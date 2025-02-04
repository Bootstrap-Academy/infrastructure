{
  config,
  lib,
  backend,
  ...
}: {
  imports = [
    backend.nixosModules.default

    ./skills.nix
    ./jobs.nix
    ./events.nix
    ./challenges.nix
  ];

  # new backend
  services.academy.backend = {
    enable = true;
    logLevel = "info";
    extraConfigFiles = [config.sops.templates."academy-backend/config".path];

    # https://github.com/Bootstrap-Academy/backend/blob/develop/config.toml
    settings = {
      http = {
        address = "127.0.0.1:8000";
        real_ip.header = "X-Real-Ip";
        real_ip.set_from = "127.0.0.1";
        allowed_origins = [
          ''^https://bootstrap\.academy$''
          ''^https://admin\.bootstrap\.academy$''
        ];
      };

      # database.run_migrations = false;

      email = {
        from = "Bootstrap Academy <noreply@bootstrap.academy>";
      };

      health = {
        email_cache_ttl = "5m";
      };

      contact = {
        email = "hallo@bootstrap.academy";
      };

      recaptcha = {
        enable = true;
        sitekey = "6Le9pMIiAAAAAAMmaH3J7ZCsQk6JcBdQtAJNXaQJ";
        min_score = 0.5;
      };

      paypal = {
        client_id = "ATyoxdWxm36bTHFypQ2lVOwDQc4lKr0CkQs6NO03HfzFjnnM-6RIre6_ycFFQDP1Iez6zVxEe6o2FHu7";
      };

      oauth2.providers = {
        github.client_id = "4f869d4f526dbb56864b";
        discord.client_id = "1034866261181607997";
        google.client_id = "418409641486-gahapigtg9ff2sldhrormm3u5b4od3r7.apps.googleusercontent.com";
      };
    };
  };

  services.nginx.virtualHosts."api.bootstrap.academy".locations."/" = {
    proxyPass = "http://127.0.0.1:8000";
    proxyWebsockets = true;
  };

  # old backend
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
      environmentFiles = [config.sops.templates."academy-backend/common".path];
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
          config.academy.backend.microservices)
        // {
          AUTH_URL = "http://127.0.0.1:8000/auth/";
          SHOP_URL = "http://127.0.0.1:8000/shop/";

          AUTH_REDIS_URL = "redis://127.0.0.1:6379/0";
          SHOP_REDIS_URL = "redis://127.0.0.1:6379/0";
        };
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

  environment.persistence."/persistent/data".directories = ["/var/lib/academy"];

  sops = {
    secrets = {
      "academy-backend/jwt-secret" = {};
      "academy-backend/recaptcha-secret" = {};
      "academy-backend/smtp-password" = {};
      "academy-backend/sentry-dsn" = {};

      "academy-backend/auth-ms/oauth/github-secret" = {};
      "academy-backend/auth-ms/oauth/discord-secret" = {};
      "academy-backend/auth-ms/oauth/google-secret" = {};

      "academy-backend/shop-ms/paypal-secret" = {};
    };
    templates = {
      "academy-backend/config" = {
        content = ''
          email.smtp_url = "smtp://noreply@bootstrap.academy:${config.sops.placeholder."academy-backend/smtp-password"}@mail.your-server.de:587?tls=required"
          jwt.secret = "${config.sops.placeholder."academy-backend/jwt-secret"}"
          recaptcha.secret = "${config.sops.placeholder."academy-backend/recaptcha-secret"}"
          paypal.client_secret = "${config.sops.placeholder."academy-backend/shop-ms/paypal-secret"}"
          sentry.dsn = "${config.sops.placeholder."academy-backend/sentry-dsn"}"
          oauth2.providers.github.client_secret = "${config.sops.placeholder."academy-backend/auth-ms/oauth/github-secret"}"
          oauth2.providers.discord.client_secret = "${config.sops.placeholder."academy-backend/auth-ms/oauth/discord-secret"}"
          oauth2.providers.google.client_secret = "${config.sops.placeholder."academy-backend/auth-ms/oauth/google-secret"}"
        '';
        owner = "academy";
        group = "academy";
      };
      "academy-backend/common".content = ''
        JWT_SECRET=${config.sops.placeholder."academy-backend/jwt-secret"}
        # RECAPTCHA_SECRET=${config.sops.placeholder."academy-backend/recaptcha-secret"}
        SMTP_PASSWORD=${config.sops.placeholder."academy-backend/smtp-password"}
      '';
    };
  };
}
