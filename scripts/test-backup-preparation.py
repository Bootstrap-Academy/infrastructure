#!/usr/bin/env python3
"""Exercise an evaluated prepare-backup script without mounts or databases.

Pass the JSON string from `nix eval --json
.#nixosConfigurations.prod.config.systemd.services.prepare-backup.script`.
Only external dump/storage commands and absolute production paths are replaced.
"""

import fcntl
import gzip
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time


SQL = b"CREATE TABLE probe (value text);\n" + b"-- retained row\n" * 10000
script = json.loads(Path(sys.argv[1]).read_text())


def check(mode, interrupted=False, reader=False):
    with tempfile.TemporaryDirectory(prefix="academy-backup-test-") as temporary:
        root = Path(temporary)
        data = root / "data"
        snapshot = data / ".snapshots/backup"
        snapshot.mkdir(parents=True)
        (snapshot / "old").write_bytes(b"known-good-backup")
        if interrupted:
            snapshot.rename(data / ".snapshots/backup.previous")
            (data / ".snapshots/backup.next").mkdir()
        commands = root / "bin"
        commands.mkdir()
        helper = commands / "helper"
        helper.write_text(
            "#!" + sys.executable + "\n"
            "import os, pathlib, shutil, sys\n"
            "mode = os.environ['FAIL_MODE']\n"
            "name = pathlib.Path(sys.argv[0]).name\n"
            "args = sys.argv[1:]\n"
            "if name == 'dump':\n"
            " sys.stdout.buffer.write(" + repr(SQL) + ")\n"
            " sys.exit(19 if mode == 'dump' else 0)\n"
            "elif name == 'compress':\n"
            " if mode == 'compress': sys.exit(20)\n"
            " os.execv(" + repr(shutil.which("gzip")) + ", ['gzip'] + args)\n"
            "elif name == 'mysql': print('-- mysql probe')\n"
            "elif name == 'mv':\n"
            " if mode == 'promote' and args[0].endswith('backup.next'): sys.exit(21)\n"
            " os.execv(" + repr(shutil.which("mv")) + ", ['mv'] + args)\n"
            "elif name == 'btrfs':\n"
            " if args[1] == 'delete': shutil.rmtree(args[2])\n"
            " else:\n"
            "  if mode == 'snapshot': sys.exit(22)\n"
            "  pathlib.Path(args[-1]).mkdir()\n"
            "  shutil.copytree(pathlib.Path(args[-2]) / 'backup', pathlib.Path(args[-1]) / 'backup')\n"
        )
        helper.chmod(0o700)
        for name in ("dump", "compress", "mysql", "btrfs", "mv"):
            (commands / name).symlink_to(helper)
        candidate = script.replace("/persistent/data", str(data)).replace(
            "/run/lock/academy-backup-snapshot.lock", str(root / "snapshot.lock")
        )
        candidate = re.sub(r"/nix/store/\S+/bin/sudo -u postgres /nix/store/\S+/bin/pg_dumpall", "dump", candidate)
        candidate = re.sub(r"/nix/store/\S+/bin/gzip", "compress", candidate)
        candidate = re.sub(r"/nix/store/\S+/bin/mysqldump", "mysql", candidate)
        environment = os.environ | {
            "PATH": str(commands) + os.pathsep + os.environ["PATH"],
            "FAIL_MODE": mode,
        }
        if reader:
            lock = (root / "snapshot.lock").open("w")
            fcntl.flock(lock, fcntl.LOCK_SH)
        process = subprocess.Popen(["bash", "-c", candidate], env=environment, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if reader:
            for _ in range(100):
                if (data / "backup/timestamp").exists():
                    break
                time.sleep(0.02)
            assert (data / "backup/timestamp").exists(), "dump did not finish"
            assert process.poll() is None, "promotion bypassed reader lock"
            assert (snapshot / "old").read_bytes() == b"known-good-backup"
            fcntl.flock(lock, fcntl.LOCK_UN)
            lock.close()
        output, errors = process.communicate(timeout=10)
        if mode != "success":
            assert process.returncode != 0, (mode, output, errors)
            assert (snapshot / "old").read_bytes() == b"known-good-backup", mode
            if mode in ("dump", "compress"):
                assert not list((data / "backup").glob("postgresql-dump.sql.gz*"))
        else:
            assert process.returncode == 0, errors
            assert gzip.decompress((snapshot / "backup/postgresql-dump.sql.gz").read_bytes()) == SQL
            assert not (data / ".snapshots/backup.next").exists()
            assert not (data / ".snapshots/backup.previous").exists()
            assert (data / "backup").stat().st_mode & 0o777 == 0o700
            assert (data / "backup/postgresql-dump.sql.gz").stat().st_mode & 0o777 == 0o600
        print("PASS", mode, "interrupted=" + str(interrupted), "reader=" + str(reader))


for failure in ("dump", "compress", "snapshot", "promote"):
    check(failure)
check("dump", interrupted=True)
check("success")
check("success", interrupted=True)
check("success", reader=True)
