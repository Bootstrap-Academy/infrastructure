{ self, testers, ... }:
let
  legacyKey = (
    builtins.head (
      builtins.match ''.*security.secret_key = "([^"]+)";.*'' (
        builtins.readFile ../hosts/prod/grafana.nix
      )
    )
  );
in
testers.runNixOSTest {
  name = "grafana-key-migration";
  nodes.machine = { pkgs, lib, ... }: {
    imports = [
      ../modules/grafana-runtime-key.nix
      ../modules/monitoring.nix
      ../modules/backup.nix
      self.inputs.sops-nix.nixosModules.default
    ];
    # Uses the same alerting provisioning as the unimported hosts/prod/alerting.nix.
    monitoring.alerting.enable = true;
    services.grafana = {
      enable = true;
      settings = {
        server.http_addr = "127.0.0.1";
        analytics = {
          reporting_enabled = false;
          check_for_updates = false;
        };
      };
    };
    monitoring.grafanaRuntimeKey = {
      enable = true;
      keyFile = "/var/lib/grafana/key";
    };
    environment.etc."grafana-test-old-key".text = legacyKey;
    environment.systemPackages = [
      self.packages.${pkgs.stdenv.hostPlatform.system}.grafana-key-migration
      (pkgs.python3.withPackages (ps: [ ps.cryptography ]))
      pkgs.curl
      pkgs.sqlite
    ];
    systemd.services.grafana-fixture = {
      before = [ "grafana.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -euo pipefail
        install -d -m 0750 -o grafana -g grafana /var/lib/grafana
        install -m 0400 -o grafana -g grafana /etc/grafana-test-old-key /var/lib/grafana/key
        install -d -m 0700 /root/migration
        ${pkgs.python3}/bin/python3 - <<'PY'
        import hashlib, json, os, secrets
        from pathlib import Path
        os.umask(0o077)
        Path("/root/migration/new-key").write_text(secrets.token_hex(32))
        key = Path("/var/lib/grafana/key").read_bytes().strip()
        ready = Path("/var/lib/grafana/runtime-key-ready.json")
        ready.write_text(json.dumps({"key_sha256": hashlib.sha256(key).hexdigest()}))
        PY
        chown root:grafana /var/lib/grafana/runtime-key-ready.json
        chmod 0440 /var/lib/grafana/runtime-key-ready.json
      '';
    };
    systemd.services.grafana = {
      requires = [ "grafana-fixture.service" ];
      after = [ "grafana-fixture.service" ];
    };
    systemd.services.secret-consumer = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig.ExecStart = "${pkgs.python3}/bin/python3 ${./grafana-key-fixture.py} serve";
    };
  };
  testScript = ''
    import json
    fixture = "python3 ${./grafana-key-fixture.py}"
    database = "/var/lib/grafana/data/grafana.db"
    machine.wait_for_unit("grafana.service")
    machine.wait_for_unit("secret-consumer.service")
    machine.wait_until_succeeds("curl -sf http://127.0.0.1:3000/api/health")
    machine.succeed(f"{fixture} seed")
    machine.succeed(f"{fixture} verify")
    machine.succeed("systemctl stop grafana")
    machine.succeed(f"{fixture} legacy {database} ${../scripts/grafana-key-migration.py}")
    machine.succeed(f"sqlite3 {database} '.backup /root/migration/old.db'")
    original_hash = machine.succeed("sha256sum /root/migration/old.db").split()[0]
    command = "grafana-key-migration --source /root/migration/old.db --old-key-file /var/lib/grafana/key --new-key-file /root/migration/new-key"

    with subtest("wrong old key and unsupported providers fail without leaving a copy"):
        machine.succeed("install -m 0600 /root/migration/new-key /root/migration/wrong-key")
        machine.fail(command.replace("--old-key-file /var/lib/grafana/key", "--old-key-file /root/migration/wrong-key") + " --output /root/migration/wrong.db")
        machine.succeed("test ! -e /root/migration/wrong.db")
        machine.succeed("cp /root/migration/old.db /root/migration/unsupported.db")
        machine.succeed("sqlite3 /root/migration/unsupported.db \"UPDATE data_keys SET provider = 'unknown'\"")
        machine.fail(command.replace("old.db", "unsupported.db") + " --output /root/migration/refused.db")
        machine.succeed("test ! -e /root/migration/refused.db")
        machine.succeed("cp /root/migration/old.db /root/migration/newstore.db")
        machine.succeed("sqlite3 /root/migration/newstore.db \"DROP TABLE IF EXISTS secret_data_key; CREATE TABLE secret_data_key (value TEXT); INSERT INTO secret_data_key VALUES ('synthetic');\"")
        machine.fail(command.replace("old.db", "newstore.db") + " --output /root/migration/newstore-refused.db")
        machine.succeed("test ! -e /root/migration/newstore-refused.db")

    with subtest("copy migration includes envelope and legacy secrets, preserving the source"):
        result = json.loads(machine.succeed(command + " --output /root/migration/new.db"))
        assert result["counts"]["data_keys"] > 0, result
        assert result["counts"]["envelope_secrets"] > 0, result
        assert result["counts"]["legacy_secrets"] > 0, result
        assert machine.succeed("sha256sum /root/migration/old.db").split()[0] == original_hash
        machine.fail(command + " --output /root/migration/new.db")
        machine.succeed("install -m 0640 -o grafana -g grafana /root/migration/new.db " + database)
        machine.succeed("install -m 0440 -o root -g grafana /root/migration/new.db.manifest.json /var/lib/grafana/runtime-key-ready.json")

    with subtest("the start guard refuses a database/key pair that is not ready"):
        machine.fail("systemctl start grafana")
        machine.succeed("install -m 0400 -o grafana -g grafana /root/migration/new-key /var/lib/grafana/key")
        machine.succeed("systemctl reset-failed grafana; systemctl start grafana")
        machine.wait_until_succeeds("curl -sf http://127.0.0.1:3000/api/health")
        machine.succeed("rm -f /tmp/contact-accepted /tmp/datasource-accepted")
        machine.succeed(f"{fixture} verify")
        machine.succeed("systemctl restart grafana")
        machine.wait_until_succeeds("curl -sf http://127.0.0.1:3000/api/health")
        machine.succeed(f"{fixture} verify")
        machine.fail("su -s /bin/sh nobody -c 'cat /var/lib/grafana/key'")

    with subtest("restore puts the original database and old key back together"):
        machine.succeed("systemctl stop grafana")
        machine.succeed("install -m 0640 -o grafana -g grafana /root/migration/old.db " + database)
        machine.succeed("install -m 0400 -o grafana -g grafana /etc/grafana-test-old-key /var/lib/grafana/key")
        machine.succeed("cp /root/migration/new.db.manifest.json /root/migration/restore.json")
        machine.succeed("python3 -c 'import hashlib,json; from pathlib import Path; p=Path(\"/var/lib/grafana/runtime-key-ready.json\"); p.write_text(json.dumps({\"key_sha256\":hashlib.sha256(Path(\"/var/lib/grafana/key\").read_bytes().strip()).hexdigest()}))'")
        machine.succeed("systemctl start grafana")
        machine.wait_until_succeeds("curl -sf http://127.0.0.1:3000/api/health")
        machine.succeed("rm -f /tmp/contact-accepted /tmp/datasource-accepted")
        machine.succeed(f"{fixture} verify")
  '';
}
