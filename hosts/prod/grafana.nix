{ env, config, ... }:

let
  domain = "grafana.bootstrap.academy";
  port = 8008;
in

{
  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = port;
        root_url = "https://${domain}/";
      };
    };
  };

  services.postgresql = {
    ensureUsers = [ { name = "grafana"; } ];
    userPasswords.grafana = config.sops.secrets."grafana/postgres_password".path;
  };

  services.nginx.virtualHosts.${domain} = {
    forceSSL = true;
    enableACME = true;
    allow = env.wg.admins ++ [ env.wg.morpheus ];
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      proxyWebsockets = true;
    };
  };

  environment.persistence."/persistent/data".directories = [ "/var/lib/grafana" ];

  sops.secrets."grafana/postgres_password" = { };
}
