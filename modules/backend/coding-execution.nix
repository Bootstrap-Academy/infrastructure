{
  config,
  lib,
  pkgs,
  challenges-ms,
  challenges-ms-develop,
  system,
  name,
  ...
}:

let
  cfg = config.academy.backend.codingExecution;
  api = config.systemd.services.academy-challenges;
in
{
  options.academy.backend.codingExecution = {
    enable = lib.mkEnableOption "separate durable coding workers (requires the leased-execution application release)";
    instances = lib.mkOption {
      type = lib.types.ints.positive;
      default = 1;
      description = "Worker processes; each retains challenges.coding_challenges.max_concurrency slots.";
    };
    package = lib.mkOption {
      type = lib.types.package;
      default =
        (if config.networking.hostName == "test" then challenges-ms-develop else challenges-ms)
        .packages.${system}.default;
      description = "The same reviewed package supplies API, worker and native migration.";
    };
    workerUnits = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      default =
        if cfg.enable then
          map (number: "academy-challenges-worker-${toString number}") (lib.range 1 cfg.instances)
        else
          [ ];
    };
  };

  config =
    lib.optionalAttrs
      (builtins.elem name [
        "test"
        "prod"
      ])
      (
        lib.mkIf cfg.enable {
          assertions = [
            {
              assertion =
                config.academy.backend.challenges.enable
                && builtins.elem config.networking.hostName [
                  "test"
                  "prod"
                ];
              message = "Separate coding workers require the existing test/prod Challenges service.";
            }
          ];

          academy.backend.challenges.settings.challenges.coding_challenges.execution.embedded_worker = false;
          systemd.services = {
            academy-challenges = {
              # One migration authority, retained at the API's existing startup point.
              preStart = lib.mkForce ''
                ${cfg.package}/bin/migration
              '';
              script = lib.mkForce ''
                exec ${cfg.package}/bin/challenges api
              '';
            };
          }
          // lib.genAttrs cfg.workerUnits (_: {
            wantedBy = [ "multi-user.target" ];
            after = lib.unique (
              api.after
              ++ [
                "network-online.target"
                "postgresql.service"
                "academy-challenges.service"
              ]
            );
            wants = lib.unique (
              api.wants
              ++ [
                "academy-challenges.service"
                "network-online.target"
              ]
            );
            inherit (api) environment restartTriggers;
            path = lib.mkForce api.path;
            # Preserve the API's actual credentials, hardening, resource and runtime
            # settings. Startup/HTTP process commands remain specific to each role.
            serviceConfig =
              builtins.removeAttrs api.serviceConfig [
                "ExecStart"
                "ExecStartPre"
                "ExecStartPost"
                "ExecReload"
                "ExecStop"
                "ExecStopPost"
                "PIDFile"
                "Type"
              ]
              // {
                Restart = "always";
                RestartSec = "5s";
                TimeoutStopSec = "30s";
              };
            # After= includes the API's native migration, but does not imply success.
            # Test that startup succeeded without coupling later API restarts to workers.
            preStart = ''
              ${pkgs.systemd}/bin/systemctl is-active --quiet academy-challenges.service
            '';
            script = ''
              exec ${cfg.package}/bin/challenges worker
            '';
          });
        }
      );
}
