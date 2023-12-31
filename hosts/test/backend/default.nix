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
    name = "Bootstrap Academy Test Instance";
    domain = "api.test.bootstrap.academy";
    frontend = "https://test.bootstrap.academy";
    corsOrigins = [".*"];

    common = {
      environmentFiles = [config.sops.templates."academy-backend/common".path];
      environment =
        {
          LOG_LEVEL = "DEBUG";

          HOST = "127.0.0.1";

          DEBUG = "True";
          RELOAD = "False";

          CACHE_TTL = "10";

          INTERNAL_JWT_TTL = "10";

          # RECAPTCHA_SITEKEY = "6Ldb070iAAAAAKsAt_M_ilgDbnWcF-N_Pj2DBBeP";
          # RECAPTCHA_MIN_SCORE = "0.5";

          SMTP_HOST = "mail.your-server.de";
          SMTP_PORT = "587";
          SMTP_USER = "noreply@bootstrap.academy";
          SMTP_FROM = "Bootstrap Academy <noreply@bootstrap.academy>";
          SMTP_TLS = "False";
          SMTP_STARTTLS = "True";

          POOL_RECYCLE = "300";
          POOL_SIZE = "20";
          MAX_OVERFLOW = "100";
          SQL_SHOW_STATEMENTS = "False";

          SENTRY_ENVIRONMENT = "test";
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

  sops = {
    secrets = {
      "academy-backend/jwt-secret" = {};
      "academy-backend/recaptcha-secret" = {};
      "academy-backend/smtp-password" = {};
    };
    templates."academy-backend/common".content = ''
      JWT_SECRET=${config.sops.placeholder."academy-backend/jwt-secret"}
      # RECAPTCHA_SECRET=${config.sops.placeholder."academy-backend/recaptcha-secret"}
      SMTP_PASSWORD=${config.sops.placeholder."academy-backend/smtp-password"}
    '';
  };
}
