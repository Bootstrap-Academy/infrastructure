{ config, lib, ... }:

let
  services = [
    "academy-backend"
    "academy-challenges"
    "academy-skills"
    "academy-task-refresh-premium"
    "academy-task-prune-database"
    "academy-task-prune-documents"
    "academy-skills-sweep-deleted-users"
    "academy-challenges-sweep-deleted-users"
  ];
  tasks = lib.drop 3 services;
in
{
  options.academy.continuousLearningRecovery = lib.mkEnableOption "maintenance recovery with the current learning migration runners";

  config = lib.mkIf config.academy.continuousLearningRecovery {
    assertions = [
      {
        assertion = builtins.elem config.networking.hostName [
          "test"
          "prod"
        ];
        message = "Learning recovery is scoped to the application hosts";
      }
    ];

    # Keep the exact current packages, settings and native migration startup.
    # This is a maintenance stop, not an old application/schema rollback.
    # No admission files are created; after reboot these writers remain held.
    # Events and Jobs retain their normal units and running processes.
    systemd.services = lib.genAttrs services (name: {
      unitConfig.ConditionPathExists = [ "/run/academy-continuous-learning-recovery-admit/${name}" ];
    });
    systemd.timers = lib.genAttrs tasks (_: {
      wantedBy = lib.mkForce [ ];
    });
  };
}
