"""Read only the durable policy; retain a sticky ingress marker across recovery.

No account data, credentials, SQL bodies or database errors are logged.
The reviewed activation procedure creates the marker before changing policy.
"""
import argparse
import os
from pathlib import Path
import subprocess
import sys


def check_policy(psql, runuser):
    def query(sql):
        result = subprocess.run(
            [runuser, "-u", "postgres", "--", psql, "-X", "-qAt", "-v", "ON_ERROR_STOP=1", "-d", "academy", "-c", sql],
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


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("prepare", "closed", "shared"), required=True)
    parser.add_argument("--marker", type=Path, required=True)
    parser.add_argument("--psql", required=True)
    parser.add_argument("--runuser", required=True)
    args = parser.parse_args()
    os.umask(0o077)
    def fence():
        args.marker.parent.mkdir(mode=0o711, parents=True, exist_ok=True)
        args.marker.parent.chmod(0o711)
        with args.marker.open("a") as stream:
            stream.flush()
            os.fsync(stream.fileno())
        directory = os.open(args.marker.parent, os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)

    try:
        if args.mode in ("closed", "shared"):
            fence()
        active, migrated = check_policy(args.psql, args.runuser)
        if active:
            fence()
        if args.mode == "shared" and not (active and migrated):
            raise ValueError("shared mode needs activated policy")
    except (OSError, ValueError, subprocess.SubprocessError):
        # An uncertain restored/missing state cannot justify legacy visibility.
        try:
            fence()
        except OSError:
            pass
        print("PRIV-01 ingress policy check failed; keep publication closed.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
