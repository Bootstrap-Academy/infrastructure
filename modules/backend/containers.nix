{
  config,
  lib,
  docker-images,
  ...
}: {
  config.virtualisation.oci-containers.containers = let
    cfg = config.academy.backend;
    microservices = builtins.filter (ms: cfg.microservices.${ms}.container != null) (builtins.attrNames cfg.microservices);
  in
    lib.mkIf cfg.enable (builtins.listToAttrs (map (ms: let
        inherit (cfg.microservices.${ms}.container) image environmentFiles environment;
      in {
        name = ms;
        value = {
          image = docker-images.${image};
          environmentFiles = cfg.common.environmentFiles ++ environmentFiles;
          environment = cfg.common.environment // environment;
          extraOptions = [
            "--rm=false"
            "--restart=always"
            "--network=host"
            "--no-healthcheck"
          ];
        };
      })
      microservices));
}
