{
  pkgs,
  config,
  docker-images,
  lib,
  ...
}: let
  port = 8100;
  redisPort = 63790;
  domain = "glitchtip.bootstrap.academy";

  base = {
    image = docker-images.glitchtip;
    extraOptions = [
      "--rm=false"
      "--restart=always"
      "--network=host"
      "--no-healthcheck"
    ];
    environmentFiles = [config.sops.secrets."glitchtip/environment".path];
    environment = {
      PORT = toString port;
      REDIS_URL = "redis://127.0.0.1:${toString redisPort}/0";
      GLITCHTIP_DOMAIN = "https://${domain}";
      DEFAULT_FROM_EMAIL = "glitchtip@the-morpheus.de";
      ENABLE_USER_REGISTRATION = "False";
      ENABLE_ORGANIZATION_CREATION = "False";
    };
    volumes = ["/var/lib/glitchtip/uploads:/code/uploads"];
  };
in {
  virtualisation.oci-containers.containers = {
    glitchtip-web = base;
    glitchtip-worker =
      base
      // {
        cmd = ["./bin/run-celery-with-beat.sh"];
      };
    glitchtip-migrate =
      base
      // {
        cmd = ["./manage.py" "migrate"];
        volumes = [];
        extraOptions = [
          "--rm=true"
          "--restart=no"
          "--network=host"
          "--no-healthcheck"
        ];
      };
  };

  systemd.services.podman-glitchtip-migrate.serviceConfig.RemainAfterExit = true;

  services.nginx.virtualHosts.${domain} = {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}/";
      proxyWebsockets = true;
    };
  };

  services.postgresql = {
    enable = true;
    ensureDatabases = ["glitchtip"];
    userPasswords.glitchtip = config.sops.secrets."glitchtip/database-password".path;
  };

  services.redis.servers.glitchtip = {
    enable = true;
    bind = null;
    port = redisPort;
    save = [];
    settings.protected-mode = "no";
  };

  system.activationScripts.initGlitchtipState = ''
    mkdir -p /var/lib/glitchtip/uploads
  '';

  backup.paths = ["/var/lib/glitchtip/uploads"];

  sops.secrets = {
    "glitchtip/database-password".owner = "postgres";
    "glitchtip/environment" = {};
  };
}
