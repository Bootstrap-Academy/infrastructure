{ config, lib, ... }:

let
  apis = [
    "academy-backend"
    "academy-skills"
    "academy-challenges"
    "academy-events"
  ];
  tasks = [
    "academy-task-refresh-premium"
    "academy-task-prune-database"
    "academy-task-prune-documents"
    "academy-skills-sweep-deleted-users"
    "academy-challenges-sweep-deleted-users"
    "academy-events-sweep-deleted-users"
  ];
in
{
  options.academy.v2Recovery = lib.mkEnableOption "V2 maintenance recovery with the current application packages and native migration runners";

  config = lib.mkIf config.academy.v2Recovery {
    assertions = [
      {
        assertion = builtins.elem config.networking.hostName [
          "test"
          "prod"
        ];
        message = "V2 recovery is scoped to the test/prod application hosts";
      }
    ];

    # Retain the exact current package, settings and migration startup for every
    # writer. Admission is never created automatically and disappears on reboot.
    # Jobs has no changed package or Coin producer in this release.
    systemd.services = lib.genAttrs (apis ++ tasks) (name: {
      unitConfig.ConditionPathExists = [ "/run/academy-v2-recovery-admit/${name}" ];
    });
    systemd.timers = lib.genAttrs tasks (_: {
      wantedBy = lib.mkForce [ ];
    });
  };
}
