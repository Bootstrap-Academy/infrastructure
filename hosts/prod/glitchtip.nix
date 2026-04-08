{
  config,
  env,
  nixpkgs-glitchtip,
  pkgs-glitchtip,
  ...
}:

let
  port = 8100;
  domain = "glitchtip.bootstrap.academy";
in

{
  disabledModules = [ "services/web-apps/glitchtip.nix" ];
  imports = [ "${nixpkgs-glitchtip}/nixos/modules/services/web-apps/glitchtip.nix" ];

  nixpkgs.overlays = [ (final: prev: { inherit (pkgs-glitchtip) glitchtip; }) ];

  services.glitchtip = {
    enable = true;
    environmentFiles = [ config.sops.templates."glitchtip/environment".path ];
    settings = {
      GRANIAN_PORT = port;
      GLITCHTIP_DOMAIN = "https://${domain}";
      DEFAULT_FROM_EMAIL = "glitchtip@the-morpheus.de";
      ENABLE_USER_REGISTRATION = false;
      ENABLE_ORGANIZATION_CREATION = false;
      GLITCHTIP_UPTIME_ALLOW_PRIVATE_IPS = true;
    };
  };

  services.nginx.virtualHosts.${domain} = {
    forceSSL = true;
    enableACME = true;
    allow = env.wg.admins ++ [ env.net.hosts ];
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}/";
      proxyWebsockets = true;
    };
  };

  sops = {
    secrets = {
      "glitchtip/secret-key" = { };
      "glitchtip/smtp-password" = { };
    };
    templates."glitchtip/environment".content = ''
      SECRET_KEY=${config.sops.placeholder."glitchtip/secret-key"}
      EMAIL_URL=smtp+tls://glitchtip@the-morpheus.de:${
        config.sops.placeholder."glitchtip/smtp-password"
      }@mail.your-server.de:587
    '';
  };
}
