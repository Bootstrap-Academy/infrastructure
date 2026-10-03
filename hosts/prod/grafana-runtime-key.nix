# Prepared activation; deliberately not imported by hosts/prod/default.nix.
# Follow docs/GRAFANA-KEY-MIGRATION.md; installing the key alone is insufficient.
{ config, ... }: {
  imports = [ ../../modules/grafana-runtime-key.nix ];
  monitoring.grafanaRuntimeKey = {
    enable = true;
    keyFile = config.sops.secrets."grafana/secret_key".path;
  };
  sops.secrets."grafana/secret_key" = {
    sopsFile = ./grafana-runtime-key.yml;
    owner = "grafana";
    group = "grafana";
    mode = "0400";
    restartUnits = [ "grafana.service" ];
  };
}
