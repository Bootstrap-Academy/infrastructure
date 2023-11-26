{
  config,
  lib,
  ...
}: {
  config = let
    cfg = config.academy.backend;
  in
    lib.mkIf cfg.enable {
      services.nginx = {
        enable = true;

        virtualHosts.${cfg.domain} = {
          forceSSL = true;
          enableACME = true;
          locations =
            lib.mapAttrs' (ms: {port, ...}: {
              name = "/${ms}/";
              value = {
                proxyPass = "http://127.0.0.1:${toString port}/";
                proxyWebsockets = true;
              };
            })
            cfg.microservices;
        };
      };
    };
}
