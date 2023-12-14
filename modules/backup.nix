{
  config,
  lib,
  pkgs,
  ...
}: {
  options.backup = with lib; {
    enable = mkEnableOption "backup";
    repo = mkOption {
      type = types.str;
    };
    passwordFile = mkOption {
      type = types.path;
    };
    paths = mkOption {
      type = types.listOf types.path;
    };
  };

  config = let
    cfg = config.backup;
    postgres = config.services.postgresql.enable;
  in
    lib.mkIf cfg.enable {
      backup.paths = ["/tmp/backup"];
      services.borgbackup.jobs.backup = {
        inherit (cfg) repo paths;
        preHook = ''
          mkdir /tmp/backup
          pushd /tmp/backup
          ${lib.optionalString postgres ''
            mkdir postgres
            ${pkgs.sudo}/bin/sudo -u postgres ${config.services.postgresql.package}/bin/pg_dumpall > postgres/dump.sql
            chmod 444 postgres/dump.sql
          ''}
          popd
        '';
        startAt = "hourly";
        prune.keep = {
          hourly = 10;
          daily = 10;
          weekly = 10;
          monthly = 10;
          yearly = 10;
        };
        encryption.mode = "repokey";
        encryption.passCommand = "cat ${cfg.passwordFile}";
        compression = "lzma,5";
        extraCreateArgs = "--stats --checkpoint-interval 600";
      };
      systemd.services.borgbackup-job-backup.serviceConfig = {
        Restart = "on-failure";
        RestartSec = "5min";
      };
    };
}
