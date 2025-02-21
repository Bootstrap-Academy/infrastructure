{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.backup = {
    targets = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            repository = lib.mkOption { type = lib.types.str; };
            repositoryPasswordFile = lib.mkOption { type = lib.types.path; };
            environmentFile = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
            };
            sshKeyFile = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
            };
          };
        }
      );
      default = { };
    };

    exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };

    prepare = lib.mkOption {
      type = lib.types.lines;
      default = "";
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "hourly";
    };
  };

  config =
    let
      cfg = config.backup;
      targets = cfg.targets;

      targetConfig =
        target:
        {
          repository,
          repositoryPasswordFile,
          environmentFile,
          sshKeyFile,
        }:
        {
          inherit repository;
          timerConfig = null;
          passwordFile = repositoryPasswordFile;
          environmentFile = lib.mkIf (environmentFile != null) environmentFile;
          extraOptions = lib.mkIf (sshKeyFile != null) [ "sftp.args='-i ${sshKeyFile}'" ];

          initialize = true;
          paths = [ "/persistent/data/.snapshots/backup" ];
          exclude = map (
            x:
            if lib.hasPrefix "/" x then
              "/persistent/data/.snapshots/backup${x}"
            else
              throw "Invalid backup exclude path: ${x}"
          ) cfg.exclude;
        };
    in
    lib.mkIf (targets != { }) {
      systemd.timers.prepare-backup.timerConfig.Persistent = true;
      systemd.services.prepare-backup = {
        startAt = cfg.schedule;
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        onSuccess = lib.mapAttrsToList (target: _: "restic-backups-${target}.service") targets;
        path = lib.attrValues { inherit (pkgs) coreutils btrfs-progs; };
        script = ''
          set -e

          if [[ -e /persistent/data/backup ]]; then
            rm -rf /persistent/data/backup
          fi

          mkdir -m 700 /persistent/data/backup
          cd /persistent/data/backup
          ${cfg.prepare}
          date --iso-8601=seconds > /persistent/data/backup/timestamp

          if [[ -e /persistent/data/.snapshots/backup ]]; then
            btrfs subvolume delete /persistent/data/.snapshots/backup
          fi
          btrfs subvolume snapshot -r /persistent/data /persistent/data/.snapshots/backup
        '';
      };

      services.restic.backups = builtins.mapAttrs targetConfig targets;
    };
}
