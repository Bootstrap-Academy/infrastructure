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
        inherit (cfg.microservices.${ms}.container) image environmentFiles environment volumes;
      in {
        name = ms;
        value = {
          inherit volumes;
          image = docker-images.${image};
          environmentFiles = cfg.common.environmentFiles ++ environmentFiles;
          environment =
            {
              PORT = toString cfg.microservices.${ms}.port;
              ROOT_PATH = "/${ms}";
              REDIS_URL = cfg.common.environment."${lib.toUpper ms}_REDIS_URL";
              PUBLIC_BASE_URL = "https://${cfg.domain}/${ms}";
            }
            // cfg.common.environment
            // environment;
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
