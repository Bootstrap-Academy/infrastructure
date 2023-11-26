{config, ...}: {
  imports = [
    ./auth.nix
    ./skills.nix
  ];

  academy.backend = {
    enable = true;
    domain = "api.test.new.bootstrap.academy";

    common = {
      environmentFiles = [config.sops.secrets."academy-backend/microservices/common".path];
      environment = {
        LOG_LEVEL = "DEBUG";

        HOST = "127.0.0.1";

        DEBUG = "True";
        RELOAD = "False";

        CACHE_TTL = "10";

        AUTH_URL = "http://127.0.0.1:8000/";
        SKILLS_URL = "http://127.0.0.1:8001/";
        SHOP_URL = "http://127.0.0.1:8002/";
        JOBS_URL = "http://127.0.0.1:8003/";
        EVENTS_URL = "http://127.0.0.1:8004/";
        CHALLENGES_URL = "http://127.0.0.1:8005/";

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

        AUTH_REDIS_URL = "redis://127.0.0.1:6379/0";
        SKILLS_REDIS_URL = "redis://127.0.0.1:6379/1";
        SHOP_REDIS_URL = "redis://127.0.0.1:6379/2";
        JOBS_REDIS_URL = "redis://127.0.0.1:6379/3";
        EVENTS_REDIS_URL = "redis://127.0.0.1:6379/4";
        CHALLENGES_REDIS_URL = "redis://127.0.0.1:6379/5";

        SENTRY_ENVIRONMENT = "test";
      };
    };
  };

  sops.secrets = {
    "academy-backend/microservices/common" = {};
  };
}
