{env, ...}: {
  services.nginx = {
    enable = true;

    appendHttpConfig = ''
      limit_req_zone $binary_remote_addr zone=sandkasten-public:10m rate=20r/m;
    '';
    virtualHosts."sandkasten.bootstrap.academy" = {
      forceSSL = true;
      enableACME = true;
      extraConfig = ''
        limit_req zone=sandkasten-public burst=5 nodelay;
        limit_req_status 429;
      '';
      locations."/" = {
        proxyPass = "http://${env.servers.sandkasten.net.private.ip4}:8000";
        proxyWebsockets = true;
      };
      locations."= /metrics".return = "403";
      locations."= /".return = "307 /docs";
    };
  };
}
