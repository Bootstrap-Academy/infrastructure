"""Exercise the lesson package location on the backend's own host through the real Nginx filters.

The evaluated http block, the backend vhost's server block and the package location
are used as they are; only the TLS listener, the storage root and the backend behind
`location /` are local fixtures. Duplicate field values are checked before an HTTP
client can collapse them into a comma-separated string.
"""

import argparse
import http.client
import json
import socket
import ssl
import subprocess
import tempfile
import time
from pathlib import Path


PACKAGE = "b" * 64
FILES = {
    "index.html": (b"<!doctype html><script type=module src=boot.js></script>\n", "text/html"),
    "boot.js": (b"import './main.js';\n", "text/javascript"),
    "main.js": (b"export const fixture = true;\n", "text/javascript"),
    "style.css": (b"body { color: red; }\n", "text/css"),
    "manifest.json": (b'{"fixture":true}', "application/json"),
    "world.svg": (b"<svg/>", "image/svg+xml"),
}
BACKEND = b"backend"
IMMUTABLE = "public, max-age=31536000, immutable"


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def run(args):
    fixture = json.loads(args.fixture.read_text())
    frontend = fixture["frontend"]
    # The contract with the frontend's loader (lesson-protocol/browser.ts, validateLessonCsp).
    policy = (
        "default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self'; connect-src 'none'; "
        "object-src 'none'; frame-src 'none'; base-uri 'none'; form-action 'none'; "
        f"frame-ancestors {frontend}; sandbox allow-scripts"
    )
    assert fixture["origin"] == "https://" + fixture["domain"], fixture["origin"]
    results = []
    with tempfile.TemporaryDirectory(prefix="lesson-package-headers-") as temporary:
        root = Path(temporary)
        content = root / "content"
        package = content / "packages" / PACKAGE
        package.mkdir(parents=True)
        for name, (data, _mime) in FILES.items():
            (package / name).write_bytes(data)
        (package / ".publish-x").write_bytes(b"hidden")
        (package / "linked.js").symlink_to(package / "main.js")
        (content / "packages" / "not-a-hash").mkdir()
        (content / "packages" / "not-a-hash" / "index.html").write_bytes(b"not a package")
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
        port = free_port()
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
                {fixture['http'].replace('@RUNTIME@', temporary)}
                server {{
                    listen 127.0.0.1:{port} ssl;
                    ssl_certificate {root}/cert.pem;
                    ssl_certificate_key {root}/key.pem;
                    {fixture['server']}
                    location ^~ /packages/ {{
                        root {content};
                        {fixture['packages']}
                    }}
                    location / {{ return 200 '{BACKEND.decode()}'; }}
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
                connection.request(method, path, headers={"Origin": frontend, **(headers or {})})
                response = connection.getresponse()
                fields = response.headers
                body = response.read()
                connection.close()
                return response.status, fields, body

            def package_file(label, path, name, method="GET", headers=None, status=200):
                actual, fields, body = request(path, method, headers)
                data, mime = FILES[name]
                assert actual == status, (label, actual)
                assert body == (data if method == "GET" and status == 200 else b""), (label, body)
                for field, value in {
                    "Content-Security-Policy": policy,
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Expose-Headers": "Content-Security-Policy",
                    "X-Content-Type-Options": "nosniff",
                    "Referrer-Policy": "no-referrer",
                    "Cache-Control": IMMUTABLE,
                    "Strict-Transport-Security": "max-age=31536000; includeSubdomains; preload",
                }.items():
                    assert fields.get_all(field) == [value], (label, field, fields.get_all(field))
                if status == 200:
                    assert fields.get_all("Content-Type") == [mime], (label, fields.get_all("Content-Type"))
                # The frame needs the entry embeddable, and the API's CORS has no business here.
                for field in (
                    "X-Frame-Options",
                    "Access-Control-Allow-Headers",
                    "Access-Control-Allow-Methods",
                    "Access-Control-Allow-Credentials",
                    "Set-Cookie",
                    "Location",
                    "Alt-Svc",
                ):
                    assert fields.get_all(field) is None, (label, field, fields.get_all(field))
                results.append({"case": label, "status": actual})
                return fields

            def refused(label, path, status=(404,), method="GET"):
                actual, fields, body = request(path, method)
                assert actual in status, (label, actual)
                assert body != BACKEND, (label, "reached the backend")
                assert fields.get_all("Cache-Control") is None, (label, fields.get_all("Cache-Control"))
                assert fields.get_all("Location") is None, label
                results.append({"case": label, "status": actual})

            base = f"/packages/{PACKAGE}/"
            fields = package_file("entry", base, "index.html")
            # A module script of the opaque frame is a CORS request with the origin "null".
            package_file("entry for an opaque document", base, "index.html", headers={"Origin": "null"})
            for name in FILES:
                if name != "index.html":
                    package_file(name, base + name, name)
            package_file("HEAD", base, "index.html", method="HEAD")
            package_file("conditional", base, "index.html", headers={"If-None-Match": fields["ETag"]}, status=304)
            refused("prefix only", "/packages/")
            refused("folder without slash", f"/packages/{PACKAGE}")
            refused("short hash", f"/packages/{PACKAGE[:63]}/")
            refused("not a hash", "/packages/not-a-hash/")
            refused("missing file", base + "missing.js")
            refused("hidden name", base + ".publish-x")
            refused("query on the entry", base + "?grant=x")
            refused("query on a file", base + "manifest.json?x")
            refused("into a foreign folder", base + "../not-a-hash/")
            refused("encoded into a foreign folder", base + "%2e%2e/not-a-hash/")
            refused("symlink", base + "linked.js", status=(403, 404))
            refused("rejected method", base, status=(403,), method="POST")
            status, fields, body = request("/control")
            assert status == 200 and body == BACKEND, (status, body)
            assert fields.get_all("Access-Control-Allow-Origin") == [frontend], fields
            assert fields.get_all("X-Frame-Options") == ["DENY"], fields
            assert fields.get_all("Referrer-Policy") == ["origin-when-cross-origin"], fields
            assert fields.get_all("Content-Security-Policy") is None, fields
            results.append({"case": "ordinary API policy unchanged", "status": status})
        finally:
            nginx.terminate()
            nginx.wait(timeout=10)
    args.output.write_text(json.dumps({"host": fixture["host"], "passed": True, "cases": results}, indent=2) + "\n")
    print(f"{fixture['host']}: {len(results)} real Nginx response checks passed")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--nginx", type=Path, required=True)
    parser.add_argument("--mime-types", type=Path, required=True)
    parser.add_argument("--fixture", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    run(parser.parse_args())
