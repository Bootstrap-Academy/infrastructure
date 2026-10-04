"""Disposable HTTP fixtures and real nginx response assertions for PRIV-01."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import sys
import threading
import urllib.error
import urllib.request


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        status = 304 if "force304" in self.path else int(self.headers.get("X-Fixture-Status", "200"))
        # A legacy upstream would reuse old person data if conditionals survived.
        if self.headers.get("If-None-Match") or self.headers.get("If-Modified-Since"):
            status = 304
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "public, max-age=3600")
        self.send_header("ETag", '"legacy-person"')
        self.send_header("Last-Modified", "Thu, 01 Oct 2026 00:00:00 GMT")
        self.end_headers()
        if status != 304 and self.command != "HEAD":
            self.wfile.write(json.dumps({"fixture": True, "path": self.path}).encode())

    do_HEAD = do_GET

    def log_message(self, *args):
        pass


def check(mode):
    def request(path, status, method="GET", headers=None):
        req = urllib.request.Request("http://127.0.0.1:8080" + path, method=method,
                                     headers={"Origin": "https://test.bootstrap.academy", **(headers or {})})
        try:
            response = urllib.request.urlopen(req)
        except urllib.error.HTTPError as error:
            response = error
        body = response.read()
        assert response.status == status, (path, response.status, status)
        assert response.headers.get_all("Cache-Control") == ["private, no-store"], (path, dict(response.headers))
        assert "Authorization" in response.headers["Vary"]
        assert "Origin" in response.headers["Vary"]
        assert response.headers.get("Access-Control-Allow-Origin") == "https://test.bootstrap.academy", (path, dict(response.headers))
        assert "ETag" not in response.headers and "Last-Modified" not in response.headers
        return body

    for path in ("/auth/_internal/profile-publications/epoch", "/auth/_internal", "/skills/_internal/skills/leaderboard", "/challenges/_internal/users/fixture"):
        request(path, 403)
    for path in ("/challenges/leaderboard", "/challenges/leaderboard/fixture", "/challenges/leaderboard/tasks/fixture", "/challenges/leaderboard/languages/python", "/profiles/fixture"):
        for method in ("GET", "HEAD"):
            body = request(path, 503 if mode == "closed" else 200, method)
            if mode == "closed":
                assert b"fixture" not in body
    for path in ("/auth/session", "/auth/sessions", "/auth/users/me", "/auth/users/me/publication", "/auth/users/me/publication-preview", "/skills/xp/fixture"):
        for status in (200, 401, 403, 404, 503):
            request(path, status, headers={"X-Fixture-Status": str(status)})
        request(path, 200, headers={"If-None-Match": '"legacy-person"', "If-Modified-Since": "Thu, 01 Oct 2026 00:00:00 GMT"})
        request(path + "?force304", 503)
    print(json.dumps({"passed": True, "mode": mode}))


if __name__ == "__main__":
    if len(sys.argv) > 1:
        check(sys.argv[2])
    else:
        for port in (8000, 8001, 8005):
            server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
            threading.Thread(target=server.serve_forever, daemon=True).start()
        threading.Event().wait()
