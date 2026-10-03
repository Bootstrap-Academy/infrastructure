{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.monitoring.grafanaRuntimeKey;
in
{
  options.monitoring.grafanaRuntimeKey = {
    enable = lib.mkEnableOption "the explicitly migrated Grafana runtime encryption key";
    keyFile = lib.mkOption {
      type = lib.types.str;
      description = "Private stable runtime key file, outside the Nix store.";
    };
    readyFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/grafana/runtime-key-ready.json";
      description = "Migration manifest installed with the matching database.";
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.grafana.package.version == "13.0.7";
        message = "Repeat the Grafana key migration VM test before changing Grafana version.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.keyFile && !(lib.hasPrefix "/nix/store/" cfg.keyFile);
        message = "Grafana requires an absolute runtime key path outside /nix/store.";
      }
      {
        assertion = config.services.grafana.settings.database.type == "sqlite3";
        message = "The reviewed Grafana runtime-key migration supports SQLite only.";
      }
    ];
    services.grafana.settings.security.secret_key = lib.mkForce "$__file{${cfg.keyFile}}";
    systemd.services.grafana.serviceConfig.ExecStartPre = lib.mkBefore [
      (lib.getExe (
        pkgs.writeShellApplication {
          name = "grafana-runtime-key-ready";
          runtimeInputs = [ pkgs.python3 ];
          text = ''
            python3 - '${cfg.keyFile}' '${cfg.readyFile}' <<'PY'
            import hashlib, json, sys
            from pathlib import Path
            key, ready = map(Path, sys.argv[1:])
            if hashlib.sha256(key.read_bytes().strip()).hexdigest() != json.loads(ready.read_text())["key_sha256"]:
                sys.exit("Grafana key and migration manifest do not match")
            PY
          '';
        }
      ))
    ];
  };
}
