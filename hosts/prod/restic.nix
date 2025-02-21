{ config, lib, ... }:
let
  repos = [
    "prod"
    "test"
  ];

  prunePolicy = [
    "--keep-hourly 48"
    "--keep-daily 14"
    "--keep-weekly 8"
    "--keep-monthly 24"
    "--keep-yearly unlimited"
  ];
in
{
  services.restic.backups = builtins.listToAttrs (
    map (repo: {
      name = "box-${repo}";
      value = {
        timerConfig = {
          OnCalendar = "04:20";
          Persistent = true;
        };
        repository = "sftp://u381435@u381435.your-storagebox.de:23/backups/${repo}";
        passwordFile = config.sops.secrets."restic/${repo}".path;
        extraOptions = [ "sftp.args='-i ${config.sops.secrets."ssh/private-key".path}'" ];

        initialize = true;

        pruneOpts = prunePolicy;

        runCheck = true;
        checkOpts = [ "--read-data-subset=4G" ];
      };
    }) repos
  );

  sops.secrets = builtins.listToAttrs (map (repo: lib.nameValuePair "restic/${repo}" { }) repos);
}
