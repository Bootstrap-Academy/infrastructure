#!/usr/bin/env python3
"""Reproduce the upstream startup-after-crash hang on disposable clusters.

Usage: test-postgres-startup-crash.py BASELINE_PACKAGE PATCHED_PACKAGE
No TCP listener, system services, or pre-existing databases are used.
"""

import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time


def probe(package, should_exit):
    binaries = Path(package) / "bin"
    with tempfile.TemporaryDirectory(prefix="academy-postgres-crash-test-") as temporary:
        root = Path(temporary)
        data = root / "db"
        socket = root / "socket"
        socket.mkdir()
        subprocess.run([str(binaries / "initdb"), "-D", str(data), "--no-sync", "--locale=C", "--encoding=UTF8"], check=True, stdout=subprocess.DEVNULL)
        with (data / "postgresql.conf").open("a") as config:
            config.write("\nlisten_addresses = ''\nunix_socket_directories = '" + str(socket) + "'\n")
        log_path = root / "server.log"
        wal_directory = data / "pg_wal"
        log = log_path.open("w")
        server = None
        sleeping = None

        def start():
            return subprocess.Popen([str(binaries / "postgres"), "-D", str(data)], stdout=log, stderr=log, start_new_session=True)

        def sql(query, check=True):
            return subprocess.run([str(binaries / "psql"), "-X", "-At", "-h", str(socket), "-d", "postgres", "-c", query], capture_output=True, text=True, check=check, timeout=5)

        def ready():
            for _ in range(200):
                if server.poll() is not None:
                    raise AssertionError(log_path.read_text())
                if sql("SELECT 1", check=False).returncode == 0:
                    return
                time.sleep(0.025)
            raise AssertionError("isolated server did not start")

        try:
            server = start()
            ready()
            sql("CREATE TABLE retained AS SELECT generate_series(1, 512) AS value")
            environment = os.environ | {"PGAPPNAME": "academy-isolated-crash-probe"}
            sleeping = subprocess.Popen([str(binaries / "psql"), "-X", "-h", str(socket), "-d", "postgres", "-c", "SELECT pg_sleep(60)"], env=environment, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            backend = None
            for _ in range(100):
                found = sql("SELECT pid FROM pg_stat_activity WHERE application_name = 'academy-isolated-crash-probe'").stdout.strip()
                if found:
                    backend = int(found)
                    break
                time.sleep(0.01)
            assert backend is not None
            # The relaunched startup process fails before redo begins, exactly
            # while FatalError is already set by the first backend crash.
            wal_directory.chmod(0)
            os.kill(backend, signal.SIGKILL)
            for _ in range(200):
                logs = log_path.read_text()
                if 'FATAL:  could not create missing directory "pg_wal/archive_status": Permission denied' in logs:
                    break
                time.sleep(0.025)
            else:
                raise AssertionError("startup failure was not reached: " + logs)
            try:
                server.wait(timeout=2)
                exited = True
            except subprocess.TimeoutExpired:
                exited = False
            assert exited == should_exit, ("unexpected postmaster state", log_path.read_text())
            if exited:
                assert server.returncode == 1, server.returncode
                assert "aborting startup due to startup process failure" in log_path.read_text()
            else:
                response = sql("SELECT 1", check=False)
                assert "in recovery mode" in response.stderr, response
                os.kill(server.pid, signal.SIGQUIT)
                server.wait(timeout=5)
            wal_directory.chmod(0o700)
            server = start()
            ready()
            assert sql("SELECT count(*), pg_is_in_recovery() FROM retained").stdout.strip() == "512|f"
            print("PASS", "patched exits cleanly" if should_exit else "baseline hang reproduced", "committed rows retained after restart")
        finally:
            wal_directory.chmod(0o700)
            if sleeping and sleeping.poll() is None:
                sleeping.terminate()
                sleeping.wait(timeout=5)
            if server and server.poll() is None:
                os.kill(server.pid, signal.SIGQUIT)
                try:
                    server.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(server.pid, signal.SIGKILL)
                    server.wait(timeout=5)
            log.close()


assert os.geteuid() != 0, "Run as an unprivileged user"
probe(sys.argv[1], should_exit=False)
probe(sys.argv[2], should_exit=True)
