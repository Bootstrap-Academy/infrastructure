{
  env,
  config,
  docker-images,
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
    environmentFiles = [config.sops.templates."glitchtip/environment".path];
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
    extraConfig = ''
      allow ${env.net.internal.net4};
      deny all;
    '';
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}/";
      proxyWebsockets = true;
    };
  };

  services.postgresql = {
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

  sops = {
    secrets = {
      "glitchtip/database-password".owner = "postgres";
      "glitchtip/secret-key" = {};
      "glitchtip/smtp-password" = {};
    };
    templates."glitchtip/environment".content = ''
      DATABASE_URL=postgres://glitchtip:${config.sops.placeholder."glitchtip/database-password"}@127.0.0.1:5432/glitchtip
      SECRET_KEY=${config.sops.placeholder."glitchtip/secret-key"}
      EMAIL_URL=smtp+tls://glitchtip@the-morpheus.de:${config.sops.placeholder."glitchtip/smtp-password"}@mail.your-server.de:587
    '';
  };
}
