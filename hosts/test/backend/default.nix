{
  config,
  lib,
  backend-develop,
  pkgs,
  ...
}: {
  imports = [
    backend-develop.nixosModules.default

    ./skills.nix
    ./jobs.nix
    ./events.nix
    ./challenges.nix
  ];

  disabledModules = [
    ../../../modules/backend/scripts.nix
  ];

  services.postgresql.package = lib.mkForce pkgs.postgresql_17;

  # new backend
  services.academy.backend = {
    enable = true;

    logLevel = "info,academy=debug";

    extraConfigFiles = [config.sops.templates."academy-backend/config".path];
    settings = {
      http = {
        address = "127.0.0.1:8000";
        real_ip.header = "X-Real-Ip";
        real_ip.set_from = "127.0.0.1";
        allowed_origins = [".*"];
      };

      # database.run_migrations = false;

      email = {
        from = "Bootstrap Academy <noreply@bootstrap.academy>";
      };

      internal = {
        shop_url = "http://127.0.0.1:8002/";
      };

      health = {
        email_cache_ttl = "5m";
      };

      user = {
        name_change_rate_limit = "1d";
        verification_redirect_url = "https://test.bootstrap.academy/auth/verify-account";
        password_reset_redirect_url = "https://test.bootstrap.academy/auth/reset-password";
        newsletter_redirect_url = "https://test.bootstrap.academy/account/newsletter";
      };

      contact = {
        email = "defelo@the-morpheus.de";
      };

      recaptcha = {
        enable = true;
        sitekey = "6Ldb070iAAAAAKsAt_M_ilgDbnWcF-N_Pj2DBBeP";
        min_score = 0.5;
      };

      paypal = {
        base_url_override = "https://api.sandbox.paypal.com";
        client_id = "AY8tdE7PPpUOVbURYdFvrqsisOiJpggHWnNYphRQjbDPCoPcD3z7XUU067hZ6kf4cH82GwQrAkJnhcqn";
      };

      oauth2.providers = {
        github.client_id = "87e19e5e68c83d9595a3";
        discord.client_id = "1019985764735537202";
        google.client_id = "887666568821-80u0pnbuemkt6ktvjlbk5judorg46alr.apps.googleusercontent.com";
      };
    };
  };

  services.nginx.virtualHosts."api.test.bootstrap.academy".locations."/" = {
    proxyPass = "http://127.0.0.1:8000";
    proxyWebsockets = true;
  };

  # old backend
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
