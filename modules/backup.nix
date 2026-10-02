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
      snapshotLock = "/run/lock/academy-backup-snapshot.lock";
      snapshotRestic = pkgs.writeShellScriptBin "restic" ''
        exec ${pkgs.util-linux}/bin/flock --shared ${snapshotLock} ${lib.getExe pkgs.restic} "$@"
      '';

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
          package = snapshotRestic;
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
      systemd.services =
        lib.mapAttrs' (
          target: _:
          lib.nameValuePair "restic-backups-${target}" {
            serviceConfig = {
              TimeoutStartSec = "30min";
              TimeoutStopSec = "30s";
            };
          }
        ) targets
        // {
          prepare-backup = {
            startAt = cfg.schedule;
            wants = [ "network-online.target" ];
            after = [ "network-online.target" ];
            onSuccess = lib.mapAttrsToList (target: _: "restic-backups-${target}.service") targets;
            path = lib.attrValues { inherit (pkgs) coreutils btrfs-progs util-linux; };
            script = ''
              set -euo pipefail
              umask 077

              snapshot=/persistent/data/.snapshots/backup
              next=/persistent/data/.snapshots/backup.next
              previous=/persistent/data/.snapshots/backup.previous
              exec 9>${snapshotLock}

              # Restore an interrupted promotion even when this dump later fails.
              if [[ ! -e "$snapshot" && -e "$previous" ]]; then
                flock --exclusive 9
                if [[ ! -e "$snapshot" && -e "$previous" ]]; then
                  mv "$previous" "$snapshot"
                fi
                flock --unlock 9
              fi

              if [[ -e /persistent/data/backup ]]; then
                rm -rf /persistent/data/backup
              fi

              mkdir -m 700 /persistent/data/backup
              cd /persistent/data/backup
              ${cfg.prepare}
              date --iso-8601=seconds > /persistent/data/backup/timestamp

              # Keep readers on one immutable snapshot for their entire run.
              flock --exclusive 9
              trap 'if [[ ! -e "$snapshot" && -e "$previous" ]]; then mv "$previous" "$snapshot"; fi' EXIT
              if [[ -e "$next" ]]; then
                btrfs subvolume delete "$next"
              fi
              btrfs subvolume snapshot -r /persistent/data "$next"

              # Only retire the old snapshot after its replacement exists.
              if [[ -e "$previous" ]]; then
                btrfs subvolume delete "$previous"
              fi
              if [[ -e "$snapshot" ]]; then
                mv "$snapshot" "$previous"
              fi
              mv "$next" "$snapshot"
              if [[ -e "$previous" ]]; then
                btrfs subvolume delete "$previous"
              fi
              trap - EXIT
            '';
          };
        };

      services.restic.backups = builtins.mapAttrs targetConfig targets;
    };
}
