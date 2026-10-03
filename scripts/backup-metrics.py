"""Record actual backup unit results atomically for the node textfile collector."""
import fcntl
import json
import os
from pathlib import Path
import sys
import time


def record(directory, unit, result):
    directory.mkdir(parents=True, exist_ok=True)
    with (directory / "lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        state_file = directory / f"{unit}.json"
        now = time.time()
        state = json.loads(state_file.read_text()) if state_file.exists() else {
            "observed_since": now, "last_success": 0, "last_failure": 0
        }
        if result == "success":
            state["last_success"] = now
        elif result != "init":
            state["last_failure"] = now
        temporary = state_file.with_suffix(".tmp")
        temporary.write_text(json.dumps(state))
        temporary.replace(state_file)
        temporary = directory / f"{unit}.tmp"
        temporary.write_text("".join(
            f'academy_backup_{key}_seconds{{service="backup",unit="{unit}"}} {value}\n'
            for key, value in state.items()
        ))
        temporary.replace(directory / f"{unit}.prom")


if __name__ == "__main__":
    os.umask(0o022)
    record(Path(sys.argv[1]), sys.argv[2], sys.argv[3])
