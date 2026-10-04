"""Bounded VM-only probes against the real pinned API and NsJail."""

import concurrent.futures
import json
import os
from pathlib import Path
import pwd
import subprocess
import time
import urllib.error
import urllib.request

ROOT = Path("/var/lib/sandkasten/programs")
GROUP = Path("/sys/fs/cgroup/system.slice/sandkasten.service")
UID = pwd.getpwnam("academy-sandbox").pw_uid
RESULTS = []


def request(language, code, route="run"):
    build = {"environment": language, "main_file": {"content": code}}
    body = {"build": build, "run": {}} if route == "run" else build
    req = urllib.request.Request(
        "http://127.0.0.1:8000/" + ("programs" if route == "build" else route),
        json.dumps(body).encode(),
        {"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=240) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as response:
        return response.code, json.load(response)


def passed(name, facts=None):
    RESULTS.append({"name": name, "passed": True, "facts": facts})
    print(json.dumps(RESULTS[-1]), flush=True)


def run(language, code, expected="OK"):
    status, data = request(language, code)
    assert status == 200, (language, status, data)
    assert data["run"]["status"] == 0, data
    assert data["run"]["stdout"].strip() == expected, data
    passed("language-" + language)
    return data


def set_last_run(program, timestamp):
    # The real pruner treats an empty/invalid timestamp as expired. Keep the old
    # value readable until the complete replacement is ready.
    temporary = program / ".last_run-probe"
    temporary.write_text(str(timestamp))
    temporary.replace(program / "last_run")


assert UID != 0
assert ROOT.is_mount()
stat = os.statvfs(ROOT)
assert stat.f_blocks * stat.f_frsize == 32 * 1024 * 1024
assert stat.f_files == 256
assert ROOT.stat().st_uid == UID
assert (GROUP / "supervisor").is_dir()
assert set((GROUP / "cgroup.controllers").read_text().split()) >= {"memory", "pids"}
passed("byte-inode-mount-and-delegation", {"bytes": stat.f_blocks * stat.f_frsize, "inodes": stat.f_files})

status, data = request("python", "import os,json\nprint(json.dumps({'uid':os.getuid(),'map':open('/proc/self/uid_map').read(),'gid_map':open('/proc/self/gid_map').read()}))")
assert status == 200 and data["run"]["status"] == 0, (status, data)
identity = json.loads(data["run"]["stdout"])
assert identity["uid"] == 65534
assert identity["map"].split() == ["65534", str(UID), "1"], identity
assert identity["gid_map"].split()[1] != "0", identity
passed("inner-nobody-maps-to-unprivileged-host", identity)
assert set((GROUP / "cgroup.subtree_control").read_text().split()) >= {"memory", "pids"}

run("python", "print('OK')")
run("java", 'class Main { public static void main(String[] args) { System.out.println("OK"); } }')
run("kotlin", 'fun main() { println("OK") }')

# Inspect two real concurrent learner processes from the host namespace.
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    futures = [pool.submit(request, "python", f"import time\ntime.sleep(4)\nprint('OK-{i}')") for i in range(2)]
    found = {}
    until = time.monotonic() + 45
    while time.monotonic() < until and len(found) < 2:
        for proc in Path("/proc").glob("[0-9]*"):
            try:
                cmd = (proc / "cmdline").read_bytes().replace(b"\0", b" ")
                if b"/program/code.py" not in cmd:
                    continue
                fields = dict(line.split(":", 1) for line in (proc / "status").read_text().splitlines() if ":" in line)
                assert int(fields["Uid"].split()[0]) == UID, fields["Uid"]
                assert int(fields["CapEff"].strip(), 16) == 0
                assert fields["NoNewPrivs"].strip() == "1"
                group = (proc / "cgroup").read_text().strip().split("::", 1)[1]
                assert group.startswith("/system.slice/sandkasten.service/NSJAIL."), group
                path = Path("/sys/fs/cgroup" + group)
                assert (path / "memory.max").read_text().strip() == "512000000"
                assert (path / "pids.max").read_text().strip() == "64"
                assert (path / "memory.swap.max").read_text().strip() == "0"
                found[proc.name] = group
            except (FileNotFoundError, ProcessLookupError):
                continue
        time.sleep(0.02)
    assert len(set(found.values())) == 2, found
    for i, future in enumerate(futures):
        status, result = future.result()
        assert status == 200 and result["run"]["stdout"].strip() == f"OK-{i}", (status, result)
passed("concurrent-host-uid-capabilities-and-cgroup-limits", found)

# A blocked network request returns a genuine program result.
status, data = request("python", "import socket\ns=socket.socket()\ns.settimeout(1)\ntry:\n s.connect(('127.0.0.1',8000))\n print('NETWORK-LEAK')\nexcept OSError:\n print('BLOCKED')")
assert status == 200 and data["run"]["stdout"].strip() == "BLOCKED", (status, data)
passed("network-disabled")

# A valid compilation can fail solely because unrelated retained artifacts occupy
# the shared budget. This is an integration gate: callers must keep it cost-free.
valid_java = 'class AMain { public static void main(String[] a) { System.out.println("OK"); } }\n'
valid_java += "\n".join(f"class Z{i} {{}}" for i in range(80))
# Earlier Kotlin/Java requests can leave expired artifacts while their real
# asynchronous pruner is still removing individual files. Wait for that work
# to finish before measuring a deliberately retained, shared-capacity fixture.
until = time.monotonic() + 30
while any(ROOT.iterdir()) and time.monotonic() < until:
    time.sleep(0.1)
assert not any(ROOT.iterdir()), list(ROOT.iterdir())
passed("prior-artifacts-fully-pruned-before-capacity-control")
run("java", valid_java + "\n// empty-cache control")
frozen = [p for p in ROOT.iterdir() if (p / "last_run").is_file()]
for p in frozen:
    set_last_run(p, int(time.time()) + 3600)
fill = """import os
from pathlib import Path
i=0
while True:
 s=os.statvfs('/program')
 remaining=s.f_bavail*s.f_frsize-98304
 if remaining<=0: break
 Path('/program/f'+str(i)).write_bytes(b'x'*min(1048576,remaining))
 i+=1
"""
status, data = request("artifact-probe", fill, route="build")
assert status == 201, (status, data)
occupied = ROOT / data["program_id"]
# Keep only this VM fixture through the independent compiler request; then let
# the real pruner remove it. No live cache or learner data is changed here.
set_last_run(occupied, int(time.time()) + 3600)
available = os.statvfs(ROOT).f_bavail * os.statvfs(ROOT).f_frsize
assert available < 98304, available
passed("unrelated-artifacts-occupy-shared-cache", {"available_bytes": available})
status, data = request("java", valid_java + "\n// occupied-cache control", route="build")
assert status == 400 and data["error"] == "compile_error", (status, data)
assert "No space left on device" in data["details"]["stderr"], data
passed("valid-compile-when-cache-occupied-needs-cost-free-caller", {"status": status, "error": data["error"]})
for p in [occupied, *frozen]:
    if (p / "last_run").is_file():
        set_last_run(p, 0)
until = time.monotonic() + 15
while occupied.exists() and time.monotonic() < until:
    time.sleep(0.1)
assert not occupied.exists()
run("java", valid_java + "\n// capacity-restored control")
passed("valid-compile-recovers-after-unrelated-cache-prune")

# Several sub-limit files must hit the aggregate mount limit, not host storage.
for kind, code in [
    ("bytes", "from pathlib import Path\nfor i in range(80):\n Path('/program/f'+str(i)).write_bytes(b'x'*1048576)"),
    ("inodes", "from pathlib import Path\nfor i in range(400):\n Path('/program/f'+str(i)).touch()"),
]:
    status, data = request("artifact-probe", code, route="build")
    assert status == 400 and data["error"] == "compile_error", (kind, status, data)
    assert "No space left on device" in data["details"]["stderr"], data
    assert os.statvfs(ROOT).f_bavail > 0 and os.statvfs(ROOT).f_favail > 0
    run("python", "print('OK') # after " + kind)
    passed("aggregate-" + kind + "-enospc-cleanup-and-retry", {"status": status})

status, data = request("artifact-probe", "from pathlib import Path\nPath('/program/retained').write_bytes(b'x'*1048576)", route="build")
assert status == 201, (status, data)
program = ROOT / data["program_id"]
assert (program / "files/retained").stat().st_size == 1048576
until = time.monotonic() + 15
while program.exists() and time.monotonic() < until:
    time.sleep(0.2)
assert not program.exists(), program
passed("successful-artifact-ttl-prune")

subprocess.run(["systemctl", "restart", "sandkasten.service"], check=True)
until = time.monotonic() + 15
while True:
    try:
        with urllib.request.urlopen("http://127.0.0.1:8000/environments", timeout=2) as response:
            assert response.status == 200
        break
    except urllib.error.URLError:
        assert time.monotonic() < until
        time.sleep(0.1)
run("python", "print('OK') # after service restart")
assert ROOT.is_mount() and ROOT.stat().st_uid == UID
assert set((GROUP / "cgroup.subtree_control").read_text().split()) >= {"memory", "pids"}
passed("service-restart-retains-cache-bound-and-recreates-delegation")

Path("/tmp/sandbox-hardening-result.json").write_text(json.dumps({"passed": True, "checks": RESULTS}, indent=2) + "\n")
