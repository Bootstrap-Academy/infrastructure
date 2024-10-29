{config, ...}: let
  domain = "cache.bootstrap.academy";
  port = 8007;
in {
  services.harmonia = {
    enable = true;
    # public key: cache.bootstrap.academy-1:unYr62tCwkIIohOUTXowIvzdqOl+0DlJNfYjEOZxdFE=
    signKeyPath = config.sops.secrets."harmonia/sign-key".path;
    settings = {
      bind = "127.0.0.1:${toString port}";
    };
  };

  services.nginx.virtualHosts.${domain} = {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      proxyWebsockets = true;
      extraConfig = ''
        zstd on;
        zstd_types application/x-nix-archive;
      '';
    };
  };

  sops.secrets."harmonia/sign-key" = {};
}
