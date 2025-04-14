{
  config,
  nixpkgs-glitchtip,
  system,
  ...
}:

let
  port = 8100;
  domain = "glitchtip.bootstrap.academy";
in

{
  imports = [ "${nixpkgs-glitchtip}/nixos/modules/services/web-apps/glitchtip.nix" ];

  services.glitchtip = {
    enable = true;
    package = nixpkgs-glitchtip.legacyPackages.${system}.glitchtip;
    inherit port;
    environmentFiles = [ config.sops.templates."glitchtip/environment".path ];
    settings = {
      GLITCHTIP_DOMAIN = "https://${domain}";
      DEFAULT_FROM_EMAIL = "glitchtip@the-morpheus.de";
      ENABLE_USER_REGISTRATION = false;
      ENABLE_ORGANIZATION_CREATION = false;
    };
  };

  services.nginx.virtualHosts.${domain} = {
    forceSSL = true;
    enableACME = true;
    extraConfig = ''
      allow 10.23.0.0/23;
      deny all;
    '';
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
