{
  config,
  pkgs,
  ...
}: let
  domain = "cache.bootstrap.academy";
  port = 8007;
in {
  services.atticd = {
    enable = true;
    environmentFile = config.sops.templates."attic/env".path;
    settings = {
      listen = "127.0.0.1:${toString port}";
      allowed-hosts = [domain];
      api-endpoint = "https://${domain}/";

      soft-delete-caches = false;
      require-proof-of-possession = true;

      database.url = "postgres://atticd@_/atticd?host=/run/postgresql";

      compression = {
        type = "zstd";
        level = 8;
      };

      garbage-collection = {
        interval = "12 hours";
        default-retention-period = "1 month";
      };
    };
  };

  services.nginx.virtualHosts.${domain} = {
    forceSSL = true;
    enableACME = true;
    extraConfig = ''
      client_max_body_size 0;
    '';
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      proxyWebsockets = true;
    };
  };

  services.postgresql = {
    enable = true;
    ensureDatabases = ["atticd"];
  };

  environment.systemPackages = [pkgs.attic-client];

  environment.persistence."/persistent/cache".directories = ["/var/lib/private/atticd"];

  sops = {
    # nix run nixpkgs#openssl -- genrsa -traditional 4096 | base64 -w0
    secrets."attic/jwt-secret".sopsFile = ./secrets.yml;
    templates."attic/env".content = ''
      ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64=${config.sops.placeholder."attic/jwt-secret"}
    '';
  };
}
