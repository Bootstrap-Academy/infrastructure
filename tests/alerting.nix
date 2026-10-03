{ self, testers, ... }:
testers.runNixOSTest {
  name = "academy-alerting";
  nodes.machine = { pkgs, lib, ... }: {
    imports = [
      ../modules/monitoring.nix
      ../modules/backup.nix
      self.inputs.sops-nix.nixosModules.default
    ];
    networking.hostName = "alert-test";
    monitoring.alerting = {
      enable = true;
      scrapeInterval = "1s";
      holdFor = "2s";
      groupWait = "1s";
      groupInterval = "5s";
      webhookFile = "/run/academy-test-webhook-url";
      probes.api = {
        url = "http://127.0.0.1:8080/health";
        module = "database";
      };
    };
    environment.systemPackages = [ pkgs.curl ];
    systemd.services.prepare-backup = {
      script = ''
        set -euo pipefail
        test ! -e /tmp/backup-failure
      '';
      serviceConfig.Type = "oneshot";
    };
    systemd.services.test-receiver = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig.ExecStart = "${pkgs.python3}/bin/python3 ${pkgs.writeText "receiver.py" ''
        import http.server, json
        from pathlib import Path
        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                self.send_response(200)
                self.end_headers()
                self.wfile.write(json.dumps({"database": not Path("/tmp/api-failure").exists(), "cache": True}).encode())
            def do_POST(self):
                body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
                with open("/tmp/webhooks.jsonl", "ab") as out:
                    out.write(json.dumps(body).encode() + b"\n")
                self.send_response(200)
                self.end_headers()
            def log_message(self, *args):
                pass
        http.server.HTTPServer(("127.0.0.1", 8080), Handler).serve_forever()
      ''}";
    };
  };
  testScript = ''
    import json
    machine.wait_for_unit("prometheus.service")
    machine.wait_for_unit("alertmanager.service")
    machine.wait_for_unit("test-receiver.service")
    machine.succeed("journalctl -u alertmanager | grep -q 'webhook URL missing; alert delivery disabled'")
    machine.wait_until_succeeds("curl -sf 'http://127.0.0.1:9090/api/v1/query?query=probe_success' | grep -q '\"1\"'")

    with subtest("actual unit failures and successful retries record separate times"):
        machine.succeed("touch /tmp/backup-failure")
        machine.fail("systemctl start prepare-backup")
        state = json.loads(machine.succeed("cat /var/lib/academy-backup-metrics/prepare-backup.json"))
        assert state["last_failure"] > 0 and state["last_success"] == 0, state
        machine.succeed("rm /tmp/backup-failure")
        machine.succeed("systemctl start prepare-backup")
        retried = json.loads(machine.succeed("cat /var/lib/academy-backup-metrics/prepare-backup.json"))
        assert retried["last_success"] > retried["last_failure"] == state["last_failure"], retried

    with subtest("database false is unhealthy even with HTTP 200"):
        machine.succeed("touch /tmp/api-failure")
        machine.wait_until_succeeds("curl -sf 'http://127.0.0.1:9090/api/v1/alerts' | grep -q AcademyServiceDown")
        machine.fail("test -e /tmp/webhooks.jsonl")

    with subtest("native webhook fires and includes a usable operational payload"):
        machine.succeed("echo http://127.0.0.1:8080/webhook > /run/academy-test-webhook-url")
        machine.succeed("chown academy-alerting:academy-alerting /run/academy-test-webhook-url; chmod 0400 /run/academy-test-webhook-url")
        machine.succeed("systemctl restart alertmanager")
        machine.wait_until_succeeds("test -s /tmp/webhooks.jsonl")
        records = [json.loads(line) for line in machine.succeed("cat /tmp/webhooks.jsonl").splitlines()]
        alerts = [a for r in records for a in r["alerts"] if a["labels"]["alertname"] == "AcademyServiceDown"]
        assert alerts and alerts[0]["status"] == "firing", records
        alert = alerts[0]
        assert alert["labels"]["host"] == "alert-test", alert
        assert alert["labels"]["service"] == "api", alert
        assert alert["startsAt"] and alert["annotations"]["link"], alert
        machine.succeed("rm /tmp/api-failure")
        machine.wait_until_succeeds("curl -sf 'http://127.0.0.1:9090/api/v1/query?query=probe_success' | grep -q '\"1\"'")
        machine.wait_until_succeeds("grep -Eq '\"status\"[[:space:]]*:[[:space:]]*\"resolved\"' /tmp/webhooks.jsonl")

    with subtest("removing the URL returns to a successful no-op"):
        machine.succeed("rm /run/academy-test-webhook-url")
        machine.succeed("systemctl restart alertmanager")
        machine.succeed("systemctl is-active alertmanager")
  '';
}
