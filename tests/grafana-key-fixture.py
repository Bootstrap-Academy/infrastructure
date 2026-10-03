"""Synthetic secrets only; used inside the NixOS Grafana migration VM."""

import base64
import http.server
import importlib.util
import json
from pathlib import Path
import sqlite3
import sys
import urllib.request


AUTH = "Basic " + base64.b64encode(b"admin:admin").decode()
DATASOURCE_AUTH = "Basic " + base64.b64encode(b"source:synthetic-datasource-password").decode()
CONTACT_AUTH = "Basic " + base64.b64encode(b"contact:synthetic-contact-password").decode()


def request(path, data=None):
    body = None if data is None else json.dumps(data).encode()
    req = urllib.request.Request("http://127.0.0.1:3000" + path, data=body,
                                 headers={"Authorization": AUTH, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as response:
        return json.load(response)


def seed():
    request("/api/datasources", {
        "name": "Fixture protected datasource", "uid": "fixture", "type": "prometheus",
        "access": "proxy", "url": "http://127.0.0.1:9080", "basicAuth": True,
        "basicAuthUser": "source", "secureJsonData": {"basicAuthPassword": "synthetic-datasource-password"},
    })
    request("/api/v1/provisioning/contact-points", {
        "uid": "fixture-contact", "name": "Fixture contact", "type": "webhook",
        "settings": {"url": "http://127.0.0.1:9080/contact", "httpMethod": "POST",
                     "username": "contact", "password": "synthetic-contact-password"},
        "disableResolveMessage": False,
    })


def verify():
    assert request("/api/datasources/proxy/uid/fixture/api/v1/query?query=up")["status"] == "success"
    receivers = request("/apis/notifications.alerting.grafana.app/v1beta1/namespaces/default/receivers")
    receiver = next(item for item in receivers["items"] if item["spec"]["title"] == "Fixture contact")
    integration = receiver["spec"]["integrations"][0]
    integration["uid"] = "fixture-contact"
    result = request("/apis/notifications.alerting.grafana.app/v1beta1/namespaces/default/receivers/"
                     + receiver["metadata"]["name"] + "/test", {
        "integration": integration, "alert": {"labels": {"alertname": "Migration VM"}, "annotations": {}},
    })
    assert Path("/tmp/contact-accepted").exists(), result
    assert request("/api/datasources/uid/academy-prometheus")["name"] == "Academy Prometheus"
    print("native datasource, stored contact secret and alerting provisioning verified")


def legacy(db_path, migration_script):
    spec = importlib.util.spec_from_file_location("migration", migration_script)
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)
    old_key = Path("/var/lib/grafana/key").read_bytes().strip()
    # Convert one real Grafana-written payload to the old direct-KEK format.
    with sqlite3.connect(db_path) as db:
        ident, value = db.execute("SELECT id, secure_json_data FROM data_source WHERE uid = 'fixture'").fetchone()
        payloads = json.loads(value)
        for key, value in payloads.items():
            blob = migration.b64decode(value)
            _, encoded_id, body = blob.split(b"#", 2)
            data_id = migration.b64decode(encoded_id.decode()).decode()
            wrapped = db.execute("SELECT encrypted_data FROM data_keys WHERE name = ?", (data_id,)).fetchone()[0]
            data_key = migration.decrypt(wrapped, old_key)
            plain = migration.decrypt(body, data_key)
            payloads[key] = base64.b64encode(migration.encrypt(plain, old_key)).decode()
        db.execute("UPDATE data_source SET secure_json_data = ? WHERE id = ?", (json.dumps(payloads), ident))


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.headers.get("Authorization") != DATASOURCE_AUTH:
            self.send_error(401)
            return
        Path("/tmp/datasource-accepted").touch()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"status":"success","data":{"resultType":"vector","result":[]}}')

    def do_POST(self):
        if self.headers.get("Authorization") != CONTACT_AUTH:
            self.send_error(401)
            return
        self.rfile.read(int(self.headers.get("Content-Length", "0")))
        Path("/tmp/contact-accepted").touch()
        self.send_response(200)
        self.end_headers()

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    if sys.argv[1] == "serve":
        http.server.HTTPServer(("127.0.0.1", 9080), Handler).serve_forever()
    elif sys.argv[1] == "seed":
        seed()
    elif sys.argv[1] == "verify":
        verify()
    elif sys.argv[1] == "legacy":
        legacy(*sys.argv[2:])
