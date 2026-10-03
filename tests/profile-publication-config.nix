{ source }:
let
  flake = builtins.getFlake source;
  describe =
    mode: recovery:
    let
      cfg =
        (flake.nixosConfigurations.test.extendModules {
          modules = [
            {
              academy.backend.profilePublication = {
                enable = true;
                inherit mode;
              };
              academy.v2Recovery = recovery;
            }
          ];
        }).config;
    in
    {
      capabilities = cfg.academy.backend.profilePublication.capabilities;
      failures = map (item: item.message) (builtins.filter (item: !item.assertion) cfg.assertions);
      backendFlag = cfg.services.academy.backend.settings.publication.enabled or null;
      skillsFlag = cfg.academy.backend.skills.settings.PROFILE_PUBLICATIONS_ENABLED or null;
      challengesFlag =
        cfg.academy.backend.challenges.settings.challenges.profile_publications_enabled or null;
      ingress = cfg.services.nginx.virtualHosts.${cfg.academy.backend.domain}.extraConfig;
      guard = cfg.systemd.services.academy-profile-publication-guard.script;
      recoveryConditions = cfg.systemd.services.academy-backend.unitConfig.ConditionPathExists or [ ];
    };
in
{
  prepare = describe "prepare" false;
  closed = describe "closed" false;
  shared = describe "shared" false;
  recovery = describe "shared" true;
}
