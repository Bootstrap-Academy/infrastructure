{ source }:

let
  flake = builtins.getFlake source;
  lib = flake.inputs.nixpkgs.lib;
  hosts = [
    "test"
    "prod"
  ];
  enabled =
    host: additions:
    (flake.nixosConfigurations.${host}.extendModules {
      modules = [
        {
          academy.backend.codingExecution.enable = true;
          academy.backend.lessonModules.enable = true;
        }
        additions
      ];
    }).config;
  describe =
    cfg:
    let
      api = cfg.systemd.services.academy-challenges;
      units = cfg.academy.backend.codingExecution.workerUnits;
      location =
        cfg.services.nginx.virtualHosts.${cfg.academy.backend.domain}.locations."^~ /lesson-modules/";
    in
    {
      apiScript = api.script;
      migrationScript = api.preStart;
      embedded =
        cfg.academy.backend.challenges.settings.challenges.coding_challenges.execution.embedded_worker;
      perWorkerCapacity =
        cfg.academy.backend.challenges.settings.challenges.coding_challenges.max_concurrency;
      totalCapacity =
        builtins.length units
        * cfg.academy.backend.challenges.settings.challenges.coding_challenges.max_concurrency;
      workers = lib.genAttrs units (
        name:
        let
          worker = cfg.systemd.services.${name};
        in
        {
          inherit (worker)
            script
            preStart
            after
            wants
            ;
          conditions = worker.unitConfig.ConditionPathExists or [ ];
          sameEnvironment = worker.environment == api.environment;
          sameEnvironmentFiles = worker.serviceConfig.EnvironmentFile == api.serviceConfig.EnvironmentFile;
          sameUser = worker.serviceConfig.User == api.serviceConfig.User;
          sameHardenedPaths = worker.path == api.path;
          sameExecutionPolicy = lib.all (key: worker.serviceConfig.${key} == api.serviceConfig.${key}) (
            builtins.attrNames (
              builtins.removeAttrs api.serviceConfig [
                "ExecStart"
                "ExecStartPre"
                "ExecStartPost"
                "ExecReload"
                "ExecStop"
                "ExecStopPost"
                "PIDFile"
                "Type"
                "Restart"
                "RestartSec"
                "TimeoutStopSec"
              ]
            )
          );
          coupledToApiStop = builtins.elem "academy-challenges.service" (
            worker.requires ++ worker.partOf ++ worker.bindsTo
          );
        }
      );
      moduleLocation = { inherit (location) root tryFiles extraConfig; };
      moduleOrigins = cfg.academy.backend.skills.settings.LESSON_MODULE_ORIGINS;
      assertions = map (item: item.message) (builtins.filter (item: !item.assertion) cfg.assertions);
    };
in
{
  disabled = lib.genAttrs [ "test" "prod" "sandkasten" ] (
    host:
    let
      cfg = flake.nixosConfigurations.${host}.config;
    in
    {
      systemDrv = cfg.system.build.toplevel.drvPath;
      workerUnits = cfg.academy.backend.codingExecution.workerUnits;
      moduleHosting = cfg.academy.backend.lessonModules.enable;
    }
  );
  enabled = lib.genAttrs hosts (host: describe (enabled host { }));
  scaled = lib.genAttrs hosts (
    host: describe (enabled host { academy.backend.codingExecution.instances = 2; })
  );
  holds = lib.genAttrs hosts (
    host:
    lib.genAttrs [ "releaseHold" "v2Recovery" "continuousLearningRecovery" ] (
      mode:
      let
        cfg = enabled host { academy.${mode} = lib.mkForce true; };
      in
      lib.genAttrs cfg.academy.backend.codingExecution.workerUnits (
        name: cfg.systemd.services.${name}.unitConfig.ConditionPathExists
      )
    )
  );
}
