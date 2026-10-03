"""Offline, copy-only migration of Grafana 13.0.7 OSS SQLite encryption.

Wire format follows pkg/services/encryption/{service,provider} and secrets/manager.
The source is never modified; the operator must stop Grafana before taking its snapshot.
"""

import argparse
import base64
import hashlib
import json
import os
import re
from pathlib import Path
import secrets
import sqlite3
import stat
import sys

from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM


class MigrationError(Exception):
    """Safe operator message, containing no secret payloads."""


def b64decode(value):
    return base64.b64decode(value + "=" * (-len(value) % 4), validate=True)


def decrypt(payload, key):
    algorithm = "aes-cfb"
    if payload.startswith(b"*"):
        _, metadata, payload = payload.split(b"*", 2)
        algorithm = b64decode(metadata.decode()).decode() or "aes-cfb"
    salt, body = payload[:8], payload[8:]
    derived = hashlib.pbkdf2_hmac("sha256", key, salt, 10000, 32)
    if algorithm == "aes-gcm":
        if len(body) < 28:
            raise MigrationError("truncated GCM ciphertext")
        return AESGCM(derived).decrypt(body[:12], body[12:], None)
    if algorithm != "aes-cfb" or len(salt) != 8 or len(body) < 16:
        raise MigrationError("unsupported or truncated ciphertext")
    cipher = Cipher(algorithms.AES(derived), modes.CFB(body[:16])).decryptor()
    return cipher.update(body[16:]) + cipher.finalize()


def encrypt(payload, key):
    salt = secrets.token_hex(4).encode()  # Grafana uses eight printable salt bytes.
    iv = os.urandom(16)
    derived = hashlib.pbkdf2_hmac("sha256", key, salt, 10000, 32)
    cipher = Cipher(algorithms.AES(derived), modes.CFB(iv)).encryptor()
    result = b"*YWVzLWNmYg*" + salt + iv + cipher.update(payload) + cipher.finalize()
    if decrypt(result, key) != payload:
        raise MigrationError("cipher round-trip failed")
    return result


def read_key(path):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_mode & 0o077:
            raise MigrationError("key file must be regular and private (0600/0400)")
        with os.fdopen(fd, "rb", closefd=False) as stream:
            key = stream.read().strip()
    finally:
        os.close(fd)
    if not key:
        raise MigrationError("empty key file")
    return key


def columns(db, table):
    return {row[1] for row in db.execute(f'PRAGMA table_info("{table}")')}


def migrate(db, old_key, new_key):
    if not {"name", "provider", "encrypted_data", "label", "scope"} <= columns(db, "data_keys"):
        raise MigrationError("unexpected data_keys schema; requires Grafana 13.0.7 OSS")
    for table in ("secret_data_key", "secret_encrypted_value"):
        if columns(db, table) and db.execute(f'SELECT count(*) FROM "{table}"').fetchone()[0]:
            raise MigrationError("unified secret stores require a separate migration review")
    data_keys = {}
    changes = []
    counts = {"data_keys": 0, "envelope_secrets": 0, "legacy_secrets": 0}
    for name, provider, blob in db.execute("SELECT name, provider, encrypted_data FROM data_keys"):
        if provider != "secretKey.v1":
            raise MigrationError("unsupported encryption provider")
        plain = decrypt(bytes(blob), old_key)
        if len(plain) != 16:
            raise MigrationError("unexpected data key length")
        data_keys[name] = plain
        changes.append((encrypt(plain, new_key), name))
    counts["data_keys"] = len(changes)

    def transform(blob):
        if blob.startswith(b"#"):
            _, encoded_id, body = blob.split(b"#", 2)
            key = data_keys[b64decode(encoded_id.decode()).decode()]
            # All supported secret types are UTF-8; validates CFB keys against real payloads.
            decrypt(body, key).decode("utf-8")
            counts["envelope_secrets"] += 1
            return blob
        plain = decrypt(blob, old_key)
        plain.decode("utf-8")
        counts["legacy_secrets"] += 1
        return encrypt(plain, new_key)

    def update_column(table, column, conversion):
        if column not in columns(db, table):
            return
        for ident, value in db.execute(f'SELECT id, "{column}" FROM "{table}"').fetchall():
            if value is None or value in ("", b"", "{}"):
                continue
            changed = conversion(value)
            if changed != value:
                db.execute(f'UPDATE "{table}" SET "{column}" = ? WHERE id = ?', (changed, ident))

    def encoded(value, padded=True):
        result = base64.b64encode(transform(b64decode(value))).decode()
        return result if padded else result.rstrip("=")

    def secure_json(value):
        data = json.loads(value)
        if not isinstance(data, dict):
            raise MigrationError("unexpected secure_json_data")
        result = {key: encoded(blob) for key, blob in data.items()}
        return value if result == data else json.dumps(result, separators=(",", ":"))

    def alert_config(value):
        data = json.loads(value)
        changed = False
        for receiver in data.get("alertmanager_config", {}).get("receivers", []):
            for managed in receiver.get("grafana_managed_receiver_configs", []):
                settings = managed.get("secureSettings", {})
                for key, blob in settings.items():
                    result = encoded(blob)
                    changed |= result != blob
                    settings[key] = result
        return json.dumps(data, separators=(",", ":")) if changed else value

    update_column("data_source", "secure_json_data", secure_json)
    update_column("plugin_setting", "secure_json_data", secure_json)
    update_column("alert_configuration", "alertmanager_configuration", alert_config)
    update_column("dashboard_snapshot", "dashboard_encrypted", lambda v: transform(bytes(v)))
    update_column("secrets", "value", lambda v: encoded(v, padded=False))
    update_column("signing_key", "private_key", lambda v: encoded(v, padded=False))
    for table, names in {
        "user_auth": ["o_auth_access_token", "o_auth_refresh_token", "o_auth_token_type", "o_auth_id_token"],
        "user_external_session": ["access_token", "id_token", "refresh_token", "session_id", "name_id"],
    }.items():
        for column in names:
            update_column(table, column, encoded)

    # These version-specific structured stores need their own inventory before expansion.
    if columns(db, "sso_setting") and db.execute("SELECT count(*) FROM sso_setting").fetchone()[0]:
        raise MigrationError("SSO settings require a separate migration review")
    if {"group", "resource"} <= columns(db, "resource"):
        count = db.execute("SELECT count(*) FROM resource WHERE \"group\" = 'provisioning.grafana.app' AND resource = 'repositories'").fetchone()[0]
        if count:
            raise MigrationError("provisioning repositories require a separate migration review")

    db.executemany("UPDATE data_keys SET encrypted_data = ? WHERE name = ?", changes)
    for name, blob in db.execute("SELECT name, encrypted_data FROM data_keys"):
        if decrypt(bytes(blob), new_key) != data_keys[name]:
            raise MigrationError("data key verification failed")
    return counts


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--old-key-file", type=Path, required=True)
    parser.add_argument("--new-key-file", type=Path, required=True)
    args = parser.parse_args()
    old_key, new_key = read_key(args.old_key_file), read_key(args.new_key_file)
    if old_key == new_key or re.fullmatch(rb"[0-9a-f]{64}", new_key) is None:
        raise MigrationError("new key must differ and contain exactly 64 hex characters")
    # CFB does not authenticate its input. This job only migrates the known public default.
    if hashlib.sha256(old_key).hexdigest() != "f3c3964ca854e172366f81d8bdb327da487c2f8a15f954b116e28961dd6585c0":
        raise MigrationError("old key is not the reviewed legacy default")
    source = args.source.resolve(strict=True)
    manifest = Path(str(args.output) + ".manifest.json")
    if manifest.exists():
        raise MigrationError("output manifest already exists")
    fd = os.open(args.output, os.O_CREAT | os.O_EXCL | os.O_WRONLY | os.O_NOFOLLOW, 0o600)
    os.close(fd)
    try:
        with sqlite3.connect(source.as_uri() + "?mode=ro", uri=True) as original:
            with sqlite3.connect(args.output) as db:
                original.backup(db)
                if db.execute("PRAGMA integrity_check").fetchall() != [("ok",)]:
                    raise MigrationError("source integrity check failed")
                db.execute("BEGIN IMMEDIATE")
                counts = migrate(db, old_key, new_key)
                db.commit()
                if db.execute("PRAGMA integrity_check").fetchall() != [("ok",)]:
                    raise MigrationError("output integrity check failed")
        result = {
            "grafana_version": "13.0.7",
            "key_sha256": hashlib.sha256(new_key).hexdigest(),
            "database_sha256": hashlib.sha256(args.output.read_bytes()).hexdigest(),
            "counts": counts,
        }
        with manifest.open("x", encoding="utf-8") as out:
            os.chmod(manifest, 0o600)
            json.dump(result, out, indent=2)
            out.write("\n")
        print(json.dumps({"status": "migrated_copy", "counts": counts}))
    except Exception:
        args.output.unlink(missing_ok=True)
        for suffix in ("-wal", "-shm", "-journal"):
            Path(str(args.output) + suffix).unlink(missing_ok=True)
        raise


if __name__ == "__main__":
    os.umask(0o077)
    try:
        main()
    except MigrationError as error:
        print(f"Migration refused; source unchanged: {error}", file=sys.stderr)
        sys.exit(1)
    except Exception:
        # Never expose decrypted values, exception arguments or SQL rows.
        print("Migration refused; source unchanged. Check key files, schema and supported stores.", file=sys.stderr)
        sys.exit(1)
