{
  services.nginx = {
    enable = true;

    appendHttpConfig = ''
      geo $sandkasten_public_limit {
        default 1;
        10.23.1.0/24 0;
      }
      map $sandkasten_public_limit $sandkasten_public_limit_key {
        0 "";
        1 $binary_remote_addr;
      }
      limit_req_zone $sandkasten_public_limit_key zone=sandkasten_public:10m rate=20r/m;
    '';
    virtualHosts."sandkasten.bootstrap.academy" = {
      forceSSL = true;
      enableACME = true;
      extraConfig = ''
        limit_req zone=sandkasten_public burst=5 nodelay;
        limit_req_status 429;
      '';
      locations."/" = {
        proxyPass = "http://10.23.0.3:8000";
        proxyWebsockets = true;
      };
      locations."= /metrics".return = "403";
      locations."= /".return = "307 /docs";
    };
  };
}
