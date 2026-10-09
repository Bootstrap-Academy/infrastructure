"""Exercise the evaluated private-content locations through the real Nginx filters.

Only the TLS listener, storage root and X-Accel upstream are local fixtures.
The upstream models both existing and header-free Skills responses. It has no
database, user data or provider connection. Duplicate field values are checked
before an HTTP client can collapse them into a comma-separated string.
"""

import argparse
import http.client
import json
import socket
import ssl
import subprocess
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


ASSET = b"export const apiVersion = 1;\nexport const fixture = 'private';\n"
ARTIFACT = "a" * 64
FILES = {
    "entry.mjs": (ASSET, "application/javascript"),
    "entry.js": (ASSET, "application/javascript"),
    "style.css": (b"body { color: red; }\n", "text/css; charset=utf-8"),
    "data.json": (b'{"fixture":true}', "application/json"),
    "image.svg": (b"<svg/>", "image/svg+xml"),
    "module.wasm": (b"\0asm\1\0\0\0", "application/wasm"),
    "unknown.bin": (b"fixture", "application/octet-stream"),
}
POLICY = {
    "Cache-Control": "private, no-store",
    "Referrer-Policy": "no-referrer",
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "Strict-Transport-Security": "max-age=31536000; includeSubdomains; preload",
}


class Upstream(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def do_HEAD(self):
        self.do_GET()

    def do_GET(self):
        _, route, grant, artifact, *asset = self.path.split("/")
        assert route == "lesson-assets"
        status = {"expired": 404, "unavailable": 503}.get(grant, 200)
        self.send_response(status)
        if grant != "current":
            # Existing Skills still sends these during a staggered rollout.
            for name in ("Cache-Control", "Referrer-Policy", "X-Content-Type-Options"):
                self.send_header(name, POLICY[name])
        if status == 200:
            self.send_header("Content-Type", FILES.get("/".join(asset), FILES["entry.mjs"])[1])
            self.send_header("X-Accel-Redirect", f"/_private-lesson-modules/{artifact}/{'/'.join(asset)}")
        self.send_header("Content-Length", "0")
        self.end_headers()


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def run(args):
    fixture = json.loads(args.fixture.read_text())
    results = []
    with tempfile.TemporaryDirectory(prefix="private-lesson-headers-") as temporary:
        root = Path(temporary)
        content = root / "modules"
        package = content / ARTIFACT
        package.mkdir(parents=True)
        for name, (data, _mime) in FILES.items():
            (package / name).write_bytes(data)
        (package / "linked.mjs").symlink_to(package / "entry.mjs")
        subprocess.run(
            [
                "openssl",
                "req",
                "-x509",
                "-newkey",
                "rsa:2048",
                "-nodes",
                "-days",
                "1",
                "-subj",
                "/CN=localhost",
                "-keyout",
                str(root / "key.pem"),
                "-out",
                str(root / "cert.pem"),
            ],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        upstream = ThreadingHTTPServer(("127.0.0.1", 0), Upstream)
        worker = threading.Thread(target=upstream.serve_forever, daemon=True)
        worker.start()
        port = free_port()
        expanded = lambda value: value.replace("@RUNTIME@", temporary).replace("@CONTENT_ROOT@", str(content))
        config = root / "nginx.conf"
        config.write_text(
            f"""
            daemon off;
            master_process off;
            pid {root}/nginx.pid;
            error_log {root}/error.log;
            events {{}}
            http {{
                include {args.mime_types};
                client_body_temp_path {root}/client-body;
                proxy_temp_path {root}/proxy;
                fastcgi_temp_path {root}/fastcgi;
                uwsgi_temp_path {root}/uwsgi;
                scgi_temp_path {root}/scgi;
                {expanded(fixture['http'])}
                server {{
                    listen 127.0.0.1:{port} ssl;
                    ssl_certificate {root}/cert.pem;
                    ssl_certificate_key {root}/key.pem;
                    {fixture['server']}
                    location ^~ /skills/lesson-assets/ {{
                        proxy_pass http://127.0.0.1:{upstream.server_port}/lesson-assets/;
                        {expanded(fixture['public'])}
                    }}
                    location ^~ /_private-lesson-modules/ {{
                        alias {content}/;
                        {expanded(fixture['private'])}
                    }}
                    location ^~ /private-lesson-modules/ {{ return 404; }}
                    location = /control {{ return 200 'ordinary API response'; }}
                }}
            }}
        """
        )
        # Fail closed on invalid evaluated directives before opening the listener.
        command = [str(args.nginx), "-e", "stderr", "-p", temporary + "/", "-c", str(config)]
        subprocess.run([*command, "-t"], check=True)
        nginx = subprocess.Popen(command)
        try:
            for _attempt in range(100):
                if nginx.poll() is not None:
                    raise AssertionError((root / "error.log").read_text())
                try:
                    with socket.create_connection(("127.0.0.1", port), timeout=0.1):
                        break
                except OSError:
                    time.sleep(0.02)
            else:
                raise AssertionError("Nginx did not open the fixture listener")

            def request(path, method="GET", headers=None):
                # The only unverified certificate is this process's local fixture.
                connection = http.client.HTTPSConnection(
                    "127.0.0.1", port, context=ssl._create_unverified_context(), timeout=5
                )
                connection.request(method, path, headers={"Origin": fixture["origin"], **(headers or {})})
                response = connection.getresponse()
                fields = response.headers
                body = response.read()
                connection.close()
                return response.status, fields, body

            def check(label, path, status=200, method="GET", headers=None, body=None):
                actual, fields, received = request(path, method, headers)
                assert actual == status, (label, actual, status)
                for name, value in POLICY.items():
                    assert fields.get_all(name) == [value], (label, name, fields.get_all(name))
                assert fields.get_all("X-Accel-Redirect") is None, label
                assert fields.get_all("Access-Control-Allow-Origin") == [fixture["origin"]], (label, fields)
                assert fields.get_all("Access-Control-Allow-Headers") == ["*, Authorization"], label
                assert fields.get_all("Access-Control-Allow-Methods") == ["*"], label
                assert fields.get_all("Access-Control-Allow-Credentials") is None, label
                assert fields.get_all("Content-Security-Policy") is None, label
                if body is not None:
                    assert received == body, (label, received)
                results.append({"case": label, "status": actual})
                return fields

            path = lambda grant, asset="entry.mjs": f"/skills/lesson-assets/{grant}/{ARTIFACT}/{asset}"
            for grant in ("legacy", "current"):
                fields = check(grant + " GET", path(grant), body=ASSET)
                assert fields.get_all("Content-Type") == ["application/javascript"], fields
                check(grant + " HEAD", path(grant), method="HEAD", body=b"")
                fields = check(
                    grant + " range", path(grant), status=206, headers={"Range": "bytes=2-8"}, body=ASSET[2:9]
                )
                assert fields["Content-Range"] == f"bytes 2-8/{len(ASSET)}", fields
                check(grant + " invalid range", path(grant), status=416, headers={"Range": "bytes=999999-"})
                check(
                    grant + " conditional", path(grant), status=304, headers={"If-None-Match": fields["ETag"]}, body=b""
                )
                check(grant + " missing file", path(grant, "missing.mjs"), status=404)
                check(grant + " symlink", path(grant, "linked.mjs"), status=403)
            for name, (data, mime) in FILES.items():
                fields = check(name + " MIME", path("current", name), body=data)
                assert fields.get_all("Content-Type") == [mime], (name, fields)
            fields = check("multipart range", path("legacy"), status=206, headers={"Range": "bytes=0-2,8-10"})
            assert fields["Content-Type"].startswith("multipart/byteranges; boundary="), fields
            check("expired grant", path("expired"), status=404, body=b"")
            check("Redis unavailable", path("unavailable"), status=503, body=b"")
            check("rejected method", path("legacy"), status=403, method="POST")
            check("direct internal", f"/_private-lesson-modules/{ARTIFACT}/entry.mjs", status=404)
            status, fields, _body = request(path("current"), headers={"Origin": "https://untrusted.invalid"})
            allowed = ["https://untrusted.invalid"] if fixture["allowOtherOrigins"] else None
            assert status == 200 and fields.get_all("Access-Control-Allow-Origin") == allowed, fields
            results.append({"case": "existing other-origin policy", "status": status})
            status, fields, body = request(path("legacy"), method="OPTIONS")
            assert status == 200 and body == b""
            assert fields.get_all("Access-Control-Allow-Origin") == [fixture["origin"]]
            results.append({"case": "vhost preflight unchanged", "status": status})
            status, fields, body = request("/control")
            assert status == 200 and body == b"ordinary API response"
            assert fields.get_all("Referrer-Policy") == ["origin-when-cross-origin"]
            assert fields.get_all("X-Content-Type-Options") == ["nosniff"]
            assert fields.get_all("Cache-Control") is None
            results.append({"case": "ordinary API policy unchanged", "status": status})
            upstream.shutdown()
            upstream.server_close()
            worker.join()
            check("upstream unavailable", path("legacy"), status=502)
        finally:
            nginx.terminate()
            nginx.wait(timeout=10)
            upstream.shutdown()
            upstream.server_close()
            worker.join(timeout=5)
    args.output.write_text(json.dumps({"host": fixture["host"], "passed": True, "cases": results}, indent=2) + "\n")
    print(f"{fixture['host']}: {len(results)} real Nginx response checks passed")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--nginx", type=Path, required=True)
    parser.add_argument("--mime-types", type=Path, required=True)
    parser.add_argument("--fixture", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    run(parser.parse_args())
