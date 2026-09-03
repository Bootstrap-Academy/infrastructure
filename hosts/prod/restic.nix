{ config, lib, ... }:
let
  repos = [
    "prod"
    "test"
  ];

  # Snapshots older than these limits are deleted on every backup target, as
  # stated in the privacy notice.
  prunePolicy = [
    "--keep-hourly 48"
    "--keep-daily 14"
    "--keep-weekly 8"
    "--keep-monthly 12"
  ];

  prune = {
    timerConfig = {
      OnCalendar = "04:20";
      Persistent = true;
    };

    initialize = true;

    pruneOpts = prunePolicy;
  };
in
{
  services.restic.backups =
    builtins.listToAttrs (
      map (repo: {
        name = "box-${repo}";
        value = prune // {
          repository = "sftp://u381435@u381435.your-storagebox.de:23/backups/${repo}";
          passwordFile = config.sops.secrets."restic/${repo}".path;
          extraOptions = [ "sftp.args='-i ${config.sops.secrets."ssh/private-key".path}'" ];

          runCheck = true;
          checkOpts = [ "--read-data-subset=4G" ];
        };
      }) repos
    )
    // {
      defelo-prod = prune // {
        inherit (config.backup.targets.defelo) repository environmentFile;
        passwordFile = config.backup.targets.defelo.repositoryPasswordFile;
      };
    };

  sops.secrets = builtins.listToAttrs (map (repo: lib.nameValuePair "restic/${repo}" { }) repos);
}
