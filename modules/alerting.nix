{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.monitoring.alerting;
  json = pkgs.formats.json { };
  backupUnits = [
    "prepare-backup"
  ]
  ++ map (target: "restic-backups-${target}") (builtins.attrNames config.backup.targets);
  metricsDirectory = "/var/lib/academy-backup-metrics";
  record = "${pkgs.python3}/bin/python3 ${../scripts/backup-metrics.py} ${metricsDirectory}";
  baseConfig = {
    route = {
      receiver = "n8n";
      group_by = [
        "host"
        "service"
      ];
      group_wait = cfg.groupWait;
      group_interval = cfg.groupInterval;
      repeat_interval = "12h";
    };
    receivers = [ { name = "n8n"; } ];
  };
  rules = import ./alerting-rules.nix {
    inherit (cfg) holdFor backupMaxAge certificateDays;
    link = cfg.runbookUrl;
  };
in
{
  options.monitoring.alerting = {
    enable = lib.mkEnableOption "native Academy operational alerting";
    webhookSecret.enable = lib.mkEnableOption "the SOPS n8n webhook secret (provision it first)";
    webhookFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/secrets/academy-alerting/n8n-webhook-url";
    };
    holdFor = lib.mkOption {
      type = lib.types.str;
      default = "2m";
    };
    groupWait = lib.mkOption {
      type = lib.types.str;
      default = "30s";
    };
    groupInterval = lib.mkOption {
      type = lib.types.str;
      default = "5m";
    };
    scrapeInterval = lib.mkOption {
      type = lib.types.str;
      default = "30s";
    };
    backupMaxAge = lib.mkOption {
      type = lib.types.ints.positive;
      default = 10800;
    };
    certificateDays = lib.mkOption {
      type = lib.types.ints.positive;
      default = 14;
    };
    runbookUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/Bootstrap-Academy/infrastructure/blob/main/docs/alerting.md";
    };
    probes = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            url = lib.mkOption { type = lib.types.str; };
            module = lib.mkOption {
              type = lib.types.str;
              default = "http";
            };
          };
        }
      );
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.monitoring.enable;
        message = "Academy alerting requires the monitoring exporters.";
      }
    ];
    users.users.academy-alerting = {
      isSystemUser = true;
      group = "academy-alerting";
    };
    users.groups.academy-alerting = { };

    services.prometheus = {
      enable = true;
      listenAddress = "127.0.0.1";
      retentionTime = "7d";
      globalConfig = {
        scrape_interval = cfg.scrapeInterval;
        evaluation_interval = cfg.scrapeInterval;
      };
      ruleFiles = [ (json.generate "academy-alerting-rules.json" rules) ];
      alertmanagers = [ { static_configs = [ { targets = [ "127.0.0.1:9093" ]; } ]; } ];
      scrapeConfigs = [
        {
          job_name = "academy-node";
          static_configs = [
            {
              targets = [ "127.0.0.1:9000" ];
              labels.host = config.networking.hostName;
            }
          ];
        }
        {
          job_name = "academy-blackbox";
          static_configs = [
            {
              targets = [ "127.0.0.1:9115" ];
              labels.host = config.networking.hostName;
            }
          ];
        }
      ]
      ++ lib.mapAttrsToList (service: probe: {
        job_name = "academy-http-${service}";
        metrics_path = "/probe";
        params.module = [ probe.module ];
        static_configs = [
          {
            targets = [ probe.url ];
            labels = {
              host = config.networking.hostName;
              inherit service;
            };
          }
        ];
        relabel_configs = [
          {
            source_labels = [ "__address__" ];
            target_label = "__param_target";
          }
          {
            source_labels = [ "__param_target" ];
            target_label = "instance";
          }
          {
            target_label = "__address__";
            replacement = "127.0.0.1:9115";
          }
          {
            target_label = "job";
            replacement = "academy-http";
          }
        ];
      }) cfg.probes;
      exporters = {
        node.extraFlags = [ "--collector.textfile.directory=${metricsDirectory}" ];
        blackbox = {
          enable = true;
          listenAddress = "127.0.0.1";
          configFile = json.generate "academy-blackbox.json" {
            modules = {
              http = {
                prober = "http";
                timeout = "10s";
                http = {
                  preferred_ip_protocol = "ip4";
                  ip_protocol_fallback = true;
                };
              };
              database = {
                prober = "http";
                timeout = "10s";
                http = {
                  preferred_ip_protocol = "ip4";
                  ip_protocol_fallback = true;
                  fail_if_body_not_matches_regexp = [
                    ''"database"\s*:\s*true''
                    ''"cache"\s*:\s*true''
                  ];
                };
              };
            };
          };
        };
      };
      alertmanager = {
        enable = true;
        listenAddress = "127.0.0.1";
        extraFlags = [ "--cluster.listen-address=" ];
        configuration = baseConfig;
      };
    };

    systemd.services =
      (lib.genAttrs backupUnits (unit: {
        unitConfig.RequiresMountsFor = [ metricsDirectory ];
        postStop = lib.mkAfter ''
          set -euo pipefail
          ${record} ${lib.escapeShellArg unit} "$SERVICE_RESULT" || echo "backup result metric could not be recorded" >&2
        '';
      }))
      // {
        alertmanager = {
          # Native delivery, grouping, resolution and retries stay in Alertmanager. The small
          # renderer handles a secret intentionally absent before notification activation.
          preStart = lib.mkForce ''
            set -euo pipefail
            ${pkgs.python3}/bin/python3 ${../scripts/alertmanager-config.py} \
              ${json.generate "academy-alertmanager-base.json" baseConfig} \
              ${lib.escapeShellArg cfg.webhookFile} /tmp/alert-manager-substituted.yaml
            ${pkgs.prometheus-alertmanager}/bin/amtool check-config /tmp/alert-manager-substituted.yaml
          '';
          serviceConfig = {
            DynamicUser = lib.mkForce false;
            User = "academy-alerting";
            Group = "academy-alerting";
          };
        };
        academy-backup-metrics = {
          wantedBy = [ "multi-user.target" ];
          before = [ "prometheus-node-exporter.service" ];
          unitConfig.RequiresMountsFor = [ metricsDirectory ];
          script = ''
            set -euo pipefail
            ${lib.concatMapStringsSep "\n" (unit: "${record} ${lib.escapeShellArg unit} init") backupUnits}
          '';
          serviceConfig.Type = "oneshot";
        };
        prometheus-node-exporter = {
          wants = [ "academy-backup-metrics.service" ];
          after = [ "academy-backup-metrics.service" ];
          unitConfig.RequiresMountsFor = [ metricsDirectory ];
        };
      };
    systemd.tmpfiles.rules = [ "d ${metricsDirectory} 0755 root root -" ];

    sops.secrets = lib.mkIf cfg.webhookSecret.enable {
      "academy-alerting/n8n-webhook-url" = {
        owner = "academy-alerting";
        group = "academy-alerting";
        restartUnits = [ "alertmanager.service" ];
      };
    };
    services.grafana.provision.enable = lib.mkIf config.services.grafana.enable true;
    services.grafana.provision.datasources.settings.datasources =
      lib.mkIf config.services.grafana.enable
        [
          {
            name = "Academy Prometheus";
            uid = "academy-prometheus";
            type = "prometheus";
            access = "proxy";
            url = "http://127.0.0.1:9090";
          }
        ];
  };
}
