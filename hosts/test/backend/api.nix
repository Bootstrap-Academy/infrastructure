{
  pkgs,
  config,
  docker-images,
  ...
}: let
  ports = {
    auth = 8000;
  };
  environment = {
    LOG_LEVEL = "DEBUG";

    HOST = "127.0.0.1";

    DEBUG = "True";
    RELOAD = "False";

    CACHE_TTL = "10";

    AUTH_URL = "http://auth:8000/";
    SKILLS_URL = "http://skills:8000/";
    SHOP_URL = "http://shop:8000/";
    JOBS_URL = "http://jobs:8000/";
    EVENTS_URL = "http://events:8000/";
    CHALLENGES_URL = "http://challenges:8000/";

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
in {
  virtualisation.oci-containers.containers = let
    extraOptions = [
      "--rm=false"
      "--restart=always"
      "--network=host"
      "--no-healthcheck"
    ];
  in {
    auth = {
      inherit extraOptions;
      image = docker-images."auth-ms:develop";
      environmentFiles = [
        config.sops.secrets."backend/api/common".path
        config.sops.secrets."backend/api/auth-ms".path
      ];
      environment =
        environment
        // {
          PORT = toString ports.auth;
          ROOT_PATH = "/auth";

          ACCESS_TOKEN_TTL = "300";
          REFRESH_TOKEN_TTL = "2592000";
          OAUTH_REGISTER_TOKEN_TTL = "600";
          HASH_TIME_COST = "2";
          HASH_MEMORY_COST = "102400";
          MFA_VALID_WINDOW = "1";
          LOGIN_FAILS_BEFORE_CAPTCHA = "3";

          CHALLENGES_LOGIN_URL = "https://develop.coding-challenges.pages.dev/login";
          EDUMATCH_LOGIN_URL = "http://localhost:8000/login";

          CONTACT_EMAIL = "defelo@the-morpheus.de";

          OPEN_REGISTRATION = "True";
          OPEN_OAUTH_REGISTRATION = "True";

          REDIS_URL = environment.AUTH_REDIS_URL;

          OAUTH_PROVIDERS__GITHUB__NAME = "GitHub";
          OAUTH_PROVIDERS__GITHUB__AUTHORIZE_URL = "https://github.com/login/oauth/authorize";
          OAUTH_PROVIDERS__GITHUB__TOKEN_URL = "https://github.com/login/oauth/access_token";
          OAUTH_PROVIDERS__GITHUB__USERINFO_URL = "https://api.github.com/user";
          OAUTH_PROVIDERS__GITHUB__USERINFO_HEADERS = ''{"Authorization": "Bearer {access_token}"}'';
          OAUTH_PROVIDERS__GITHUB__USERINFO_ID_PATH = ".id";
          OAUTH_PROVIDERS__GITHUB__USERINFO_NAME_PATH = ".login";

          OAUTH_PROVIDERS__DISCORD__NAME = "Discord";
          OAUTH_PROVIDERS__DISCORD__AUTHORIZE_URL = "https://discord.com/api/oauth2/authorize?scope=identify";
          OAUTH_PROVIDERS__DISCORD__TOKEN_URL = "https://discord.com/api/oauth2/token";
          OAUTH_PROVIDERS__DISCORD__USERINFO_URL = "https://discord.com/api/v9/users/@me";
          OAUTH_PROVIDERS__DISCORD__USERINFO_HEADERS = ''{"Authorization": "Bearer {access_token}"}'';
          OAUTH_PROVIDERS__DISCORD__USERINFO_ID_PATH = ".id";
          OAUTH_PROVIDERS__DISCORD__USERINFO_NAME_PATH = ''.username+"#"+.discriminator'';

          OAUTH_PROVIDERS__GOOGLE__NAME = "Google";
          OAUTH_PROVIDERS__GOOGLE__AUTHORIZE_URL = "https://accounts.google.com/o/oauth2/auth?scope=openid%20profile";
          OAUTH_PROVIDERS__GOOGLE__TOKEN_URL = "https://oauth2.googleapis.com/token";
          OAUTH_PROVIDERS__GOOGLE__USERINFO_URL = "https://www.googleapis.com/oauth2/v3/userinfo";
          OAUTH_PROVIDERS__GOOGLE__USERINFO_HEADERS = ''{"Authorization": "Bearer {access_token}"}'';
          OAUTH_PROVIDERS__GOOGLE__USERINFO_ID_PATH = ".sub";
          OAUTH_PROVIDERS__GOOGLE__USERINFO_NAME_PATH = ".given_name";
        };
    };
  };

  services.nginx.virtualHosts."api.test.new.bootstrap.academy" = {
    forceSSL = true;
    enableACME = true;
    locations."/auth/" = {
      proxyPass = "http://127.0.0.1:${toString ports.auth}/";
      proxyWebsockets = true;
    };
  };

  sops.secrets = {
    "backend/api/common" = {};
    "backend/api/auth-ms" = {};
  };
}
