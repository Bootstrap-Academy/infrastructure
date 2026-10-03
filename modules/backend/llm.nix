{
  config,
  llm-ms,
  lib,
  ...
}:
{
  imports = [ llm-ms.nixosModules.default ];
  options.academy.backend.llm.enable = lib.mkEnableOption "the disabled LLM gateway";
  config = lib.mkIf config.academy.backend.llm.enable {
    services.academy.llm = {
      enable = true;
      settings = {
        providers.mode = "disabled";
        http.address = "127.0.0.1:8006";
      };
    };
    # Disabled mode needs no database or credentials; adding unused registry URLs would
    # unnecessarily restart the existing microservices.
    services.nginx.virtualHosts.${config.academy.backend.domain}.locations."/llm/" = {
      proxyPass = "http://127.0.0.1:8006/";
      extraConfig = ''
        proxy_buffering off;
        proxy_read_timeout 210s;
        client_max_body_size 128k;
      '';
    };
  };
}
