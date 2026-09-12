{ config, lib, ... }:

let
  units = [
    "academy-backend"
    "academy-events"
    "academy-skills"
    "academy-jobs"
    "academy-challenges"
    "academy-task-refresh-premium"
    "academy-task-prune-database"
    "academy-task-prune-documents"
    "academy-events-sweep-deleted-users"
    "academy-skills-sweep-deleted-users"
    "academy-challenges-sweep-deleted-users"
  ];
in
{
  options.academy.releaseHold = lib.mkEnableOption "explicit per-service admission during a coordinated release";

  config = lib.mkIf config.academy.releaseHold {
    assertions = [
      {
        assertion = builtins.elem config.networking.hostName [
          "prod"
          "test"
        ];
        message = "The Academy release hold is scoped to the prod/test application hosts";
      }
    ];

    # No file is created here. After a reboot every application writer is held
    # again. Removing a file does not stop an already running process.
    systemd.tmpfiles.rules = [ "d /run/academy-release-allow 0700 root root -" ];
    systemd.services = lib.genAttrs units (name: {
      unitConfig.ConditionPathExists = [ "/run/academy-release-allow/${name}" ];
    });
  };
}
