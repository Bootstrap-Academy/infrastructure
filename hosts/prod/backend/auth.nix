{
  config,
  lib,
  auth-ms,
  ...
}: let
  ms = "auth";
in {
  imports = [auth-ms.nixosModules.default];

  academy.backend.microservices.auth = {
    port = 8000;
    database = {};
    redis.database = 0;
  };

  academy.backend.auth = {
    enable = true;
    environmentFiles =
      config.academy.backend.common.environmentFiles
      ++ [config.sops.templates."academy-backend/auth-ms".path];
    settings =
      config.academy.backend.common.environment
      // {
        PORT = toString config.academy.backend.microservices.${ms}.port;
        ROOT_PATH = "/${ms}";
        REDIS_URL = config.academy.backend.common.environment."${lib.toUpper ms}_REDIS_URL";
        PUBLIC_BASE_URL = "https://${config.academy.backend.domain}/${ms}";
        DATABASE_URL = "postgresql+asyncpg://academy-${ms}@/academy-${ms}?host=/run/postgresql";

        ACCESS_TOKEN_TTL = "300";
        REFRESH_TOKEN_TTL = "2592000";
        OAUTH_REGISTER_TOKEN_TTL = "600";
        HASH_TIME_COST = "2";
        HASH_MEMORY_COST = "102400";
        MFA_VALID_WINDOW = "1";
        LOGIN_FAILS_BEFORE_CAPTCHA = "3";
        MIN_NAME_CHANGE_INTERVAL = "30"; # days

        ADMIN_USERNAME = "admin";
        ADMIN_EMAIL = "admin@bootstrap.academy";

        FRONTEND_BASE_URL = config.academy.backend.frontend;

        CONTACT_EMAIL = "hallo@bootstrap.academy";

        OPEN_REGISTRATION = "True";
        OPEN_OAUTH_REGISTRATION = "True";

        OAUTH_PROVIDERS__GITHUB__NAME = "GitHub";
        OAUTH_PROVIDERS__GITHUB__CLIENT_ID = "4f869d4f526dbb56864b";
        OAUTH_PROVIDERS__GITHUB__AUTHORIZE_URL = "https://github.com/login/oauth/authorize";
        OAUTH_PROVIDERS__GITHUB__TOKEN_URL = "https://github.com/login/oauth/access_token";
        OAUTH_PROVIDERS__GITHUB__USERINFO_URL = "https://api.github.com/user";
        OAUTH_PROVIDERS__GITHUB__USERINFO_HEADERS = ''{"Authorization": "Bearer {access_token}"}'';
        OAUTH_PROVIDERS__GITHUB__USERINFO_ID_PATH = ".id";
        OAUTH_PROVIDERS__GITHUB__USERINFO_NAME_PATH = ".login";

        OAUTH_PROVIDERS__DISCORD__NAME = "Discord";
        OAUTH_PROVIDERS__DISCORD__CLIENT_ID = "1034866261181607997";
        OAUTH_PROVIDERS__DISCORD__AUTHORIZE_URL = "https://discord.com/api/oauth2/authorize?scope=identify";
        OAUTH_PROVIDERS__DISCORD__TOKEN_URL = "https://discord.com/api/oauth2/token";
        OAUTH_PROVIDERS__DISCORD__USERINFO_URL = "https://discord.com/api/v9/users/@me";
        OAUTH_PROVIDERS__DISCORD__USERINFO_HEADERS = ''{"Authorization": "Bearer {access_token}"}'';
        OAUTH_PROVIDERS__DISCORD__USERINFO_ID_PATH = ".id";
        OAUTH_PROVIDERS__DISCORD__USERINFO_NAME_PATH = ''.username+"#"+.discriminator'';

        OAUTH_PROVIDERS__GOOGLE__NAME = "Google";
        OAUTH_PROVIDERS__GOOGLE__CLIENT_ID = "418409641486-gahapigtg9ff2sldhrormm3u5b4od3r7.apps.googleusercontent.com";
        OAUTH_PROVIDERS__GOOGLE__AUTHORIZE_URL = "https://accounts.google.com/o/oauth2/auth?scope=openid%20profile";
        OAUTH_PROVIDERS__GOOGLE__TOKEN_URL = "https://oauth2.googleapis.com/token";
        OAUTH_PROVIDERS__GOOGLE__USERINFO_URL = "https://www.googleapis.com/oauth2/v3/userinfo";
        OAUTH_PROVIDERS__GOOGLE__USERINFO_HEADERS = ''{"Authorization": "Bearer {access_token}"}'';
        OAUTH_PROVIDERS__GOOGLE__USERINFO_ID_PATH = ".sub";
        OAUTH_PROVIDERS__GOOGLE__USERINFO_NAME_PATH = ".given_name";
      };
  };

  sops = {
    secrets = {
      "academy-backend/auth-ms/sentry-dsn" = {};
      "academy-backend/auth-ms/admin-password" = {};
      "academy-backend/auth-ms/oauth/github-secret" = {};
      "academy-backend/auth-ms/oauth/discord-secret" = {};
      "academy-backend/auth-ms/oauth/google-secret" = {};
    };
    templates."academy-backend/auth-ms".content = ''
      SENTRY_DSN=${config.sops.placeholder."academy-backend/auth-ms/sentry-dsn"}
      ADMIN_PASSWORD=${config.sops.placeholder."academy-backend/auth-ms/admin-password"}
      OAUTH_PROVIDERS__GITHUB__CLIENT_SECRET=${config.sops.placeholder."academy-backend/auth-ms/oauth/github-secret"}
      OAUTH_PROVIDERS__DISCORD__CLIENT_SECRET=${config.sops.placeholder."academy-backend/auth-ms/oauth/discord-secret"}
      OAUTH_PROVIDERS__GOOGLE__CLIENT_SECRET=${config.sops.placeholder."academy-backend/auth-ms/oauth/google-secret"}
    '';
  };
}
