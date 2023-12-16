{
  config,
  lib,
  ...
}: {
  imports = [
    ./auth.nix
    ./skills.nix
    ./shop.nix
    ./jobs.nix
    ./events.nix
    ./challenges.nix
  ];

  academy.backend = {
    enable = true;
    name = "Bootstrap Academy Production Instance";
    domain = "api.bootstrap.academy";
    frontend = "https://bootstrap.academy";
    corsOrigins = [
      "^https://bootstrap.academy$"
      "^https://admin.bootstrap.academy$"
    ];

    common = {
      environmentFiles = [config.sops.secrets."academy-backend/microservices/common".path];
      environment =
        {
          LOG_LEVEL = "INFO";

          HOST = "127.0.0.1";

          DEBUG = "False";
          RELOAD = "False";

          CACHE_TTL = "300";

          INTERNAL_JWT_TTL = "10";

          RECAPTCHA_SITEKEY = "6Le9pMIiAAAAAAMmaH3J7ZCsQk6JcBdQtAJNXaQJ";
          RECAPTCHA_MIN_SCORE = "0.5";

          SMTP_HOST = "mail.your-server.de";
          SMTP_PORT = "587";
          SMTP_USER = "noreply@bootstrap.academy";
          SMTP_FROM = "Bootstrap Academy <noreply@bootstrap.academy>";
          SMTP_TLS = "False";
          SMTP_STARTTLS = "True";

          POOL_RECYCLE = "300";
          POOL_SIZE = "10";
          MAX_OVERFLOW = "10";
          SQL_SHOW_STATEMENTS = "False";

          SENTRY_ENVIRONMENT = "prod";
        }
        // (lib.mapAttrs' (ms: {port, ...}: {
            name = "${lib.toUpper ms}_URL";
            value = "http://127.0.0.1:${toString port}/";
          })
          config.academy.backend.microservices)
        // (lib.mapAttrs' (ms: {redis, ...}: {
            name = "${lib.toUpper ms}_REDIS_URL";
            value = "redis://127.0.0.1:6379/${toString redis.database}";
          })
          config.academy.backend.microservices);
    };
  };

  services.sshfs.mounts."/mnt/lectures" = {
    host = "u381435.your-storagebox.de";
    port = 23;
    user = "u381435";
    path = "lectures";
    readOnly = true;
    allowOther = true;
  };

  sops.secrets = {
    "academy-backend/microservices/common" = {};
  };
}
