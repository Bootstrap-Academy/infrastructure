"""Read only the durable policy; open ingress through a runtime release flag.

No account data, credentials, SQL bodies or database errors are logged.
Nginx serves rankings and profile projections only while the release flag of
its own mode exists. Every failed run removes the flags, so an unavailable
database closes these surfaces without stopping Nginx. The persistent marker
records an activated policy; the reviewed activation procedure creates it in
closed mode before changing policy.
"""
import argparse
import os
from pathlib import Path
import subprocess
import sys

RELEASING = ("prepare", "shared")


def check_policy(psql, runuser, database):
    def query(sql):
        result = subprocess.run(
            [runuser, "-u", "postgres", "--", psql, "-X", "-qAt", "-v", "ON_ERROR_STOP=1", "-d", database, "-c", sql],
            capture_output=True, text=True, timeout=15,
            env={"PATH": os.environ.get("PATH", ""), "PGCONNECT_TIMEOUT": "5"},
        )
        if result.returncode:
            raise ValueError("policy unavailable")
        return result.stdout.strip()

    exists = query("BEGIN READ ONLY; SELECT to_regclass('public.profile_publication_state') IS NOT NULL; COMMIT;")
    if exists == "f":
        return False, False
    if exists != "t":
        raise ValueError("invalid policy state")
    state = query("BEGIN READ ONLY; SELECT policy_active::text || ':' || coalesce(scope_version, '') FROM public.profile_publication_state WHERE singleton; COMMIT;")
    if state == "false:" or state == "false:academy-verified-v1":
        return False, True
    if state != "true:academy-verified-v1":
        raise ValueError("invalid policy state")
    return True, True


def fence(marker):
    marker.parent.mkdir(mode=0o711, parents=True, exist_ok=True)
    marker.parent.chmod(0o711)
    with marker.open("a") as stream:
        stream.flush()
        os.fsync(stream.fileno())
    directory = os.open(marker.parent, os.O_DIRECTORY)
    try:
        os.fsync(directory)
    finally:
        os.close(directory)


def release(directory, mode):
    """Keep only the flag of a successfully checked mode; None closes all."""
    directory.mkdir(mode=0o711, parents=True, exist_ok=True)
    directory.chmod(0o711)
    for name in RELEASING:
        if name != mode:
            (directory / ("released-" + name)).unlink(missing_ok=True)
    if mode is not None:
        (directory / ("released-" + mode)).touch(mode=0o600)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("prepare", "closed", "shared", "recovery"), required=True)
    parser.add_argument("--activated", action="store_true")
    parser.add_argument("--marker", type=Path, required=True)
    parser.add_argument("--release-dir", type=Path, required=True)
    parser.add_argument("--database", required=True)
    parser.add_argument("--psql", required=True)
    parser.add_argument("--runuser", required=True)
    args = parser.parse_args()
    os.umask(0o077)
    # Before activation, prepare and recovery fence only on an active policy, so
    # a database outage or recovery closes legacy rankings just until the next run.
    always_fence = args.mode in ("closed", "shared") or args.activated
    try:
        if always_fence:
            fence(args.marker)
        active, migrated = check_policy(args.psql, args.runuser, args.database)
        if active:
            fence(args.marker)
        if args.mode == "shared" and not (active and migrated):
            raise ValueError("shared mode needs activated policy")
        opened = args.mode == "shared" or (args.mode == "prepare" and not active and not args.marker.exists())
        release(args.release_dir, args.mode if opened else None)
    except Exception:
        # An uncertain restored/missing state cannot justify any visibility.
        try:
            release(args.release_dir, None)
        except OSError:
            pass
        if always_fence:
            try:
                fence(args.marker)
            except OSError:
                pass
        print("PRIV-01 ingress policy check failed; keep publication closed.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
