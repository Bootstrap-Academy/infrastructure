{config, ...}: {
  academy.backend.microservices.auth = {
    port = 8000;
    database.passwordFile = config.sops.secrets."academy-backend/database/passwords/academy-auth".path;
    redis.database = 0;
    container = {
      image = "auth-ms:develop";
      environmentFiles = [config.sops.secrets."academy-backend/microservices/auth-ms".path];
      environment = {
        ACCESS_TOKEN_TTL = "300";
        REFRESH_TOKEN_TTL = "2592000";
        OAUTH_REGISTER_TOKEN_TTL = "600";
        HASH_TIME_COST = "2";
        HASH_MEMORY_COST = "102400";
        MFA_VALID_WINDOW = "1";
        LOGIN_FAILS_BEFORE_CAPTCHA = "3";

        CONTACT_EMAIL = "defelo@the-morpheus.de";

        OPEN_REGISTRATION = "True";
        OPEN_OAUTH_REGISTRATION = "True";

        OAUTH_PROVIDERS__GITHUB__NAME = "GitHub";
        OAUTH_PROVIDERS__GITHUB__CLIENT_ID = "87e19e5e68c83d9595a3";
        OAUTH_PROVIDERS__GITHUB__AUTHORIZE_URL = "https://github.com/login/oauth/authorize";
        OAUTH_PROVIDERS__GITHUB__TOKEN_URL = "https://github.com/login/oauth/access_token";
        OAUTH_PROVIDERS__GITHUB__USERINFO_URL = "https://api.github.com/user";
        OAUTH_PROVIDERS__GITHUB__USERINFO_HEADERS = ''{"Authorization": "Bearer {access_token}"}'';
        OAUTH_PROVIDERS__GITHUB__USERINFO_ID_PATH = ".id";
        OAUTH_PROVIDERS__GITHUB__USERINFO_NAME_PATH = ".login";

        OAUTH_PROVIDERS__DISCORD__NAME = "Discord";
        OAUTH_PROVIDERS__DISCORD__CLIENT_ID = "1019985764735537202";
        OAUTH_PROVIDERS__DISCORD__AUTHORIZE_URL = "https://discord.com/api/oauth2/authorize?scope=identify";
        OAUTH_PROVIDERS__DISCORD__TOKEN_URL = "https://discord.com/api/oauth2/token";
        OAUTH_PROVIDERS__DISCORD__USERINFO_URL = "https://discord.com/api/v9/users/@me";
        OAUTH_PROVIDERS__DISCORD__USERINFO_HEADERS = ''{"Authorization": "Bearer {access_token}"}'';
        OAUTH_PROVIDERS__DISCORD__USERINFO_ID_PATH = ".id";
        OAUTH_PROVIDERS__DISCORD__USERINFO_NAME_PATH = ''.username+"#"+.discriminator'';

        OAUTH_PROVIDERS__GOOGLE__NAME = "Google";
        OAUTH_PROVIDERS__GOOGLE__CLIENT_ID = "887666568821-80u0pnbuemkt6ktvjlbk5judorg46alr.apps.googleusercontent.com";
        OAUTH_PROVIDERS__GOOGLE__AUTHORIZE_URL = "https://accounts.google.com/o/oauth2/auth?scope=openid%20profile";
        OAUTH_PROVIDERS__GOOGLE__TOKEN_URL = "https://oauth2.googleapis.com/token";
        OAUTH_PROVIDERS__GOOGLE__USERINFO_URL = "https://www.googleapis.com/oauth2/v3/userinfo";
        OAUTH_PROVIDERS__GOOGLE__USERINFO_HEADERS = ''{"Authorization": "Bearer {access_token}"}'';
        OAUTH_PROVIDERS__GOOGLE__USERINFO_ID_PATH = ".sub";
        OAUTH_PROVIDERS__GOOGLE__USERINFO_NAME_PATH = ".given_name";
      };
    };
  };

  sops.secrets = {
    "academy-backend/database/passwords/academy-auth".owner = "postgres";
    "academy-backend/microservices/auth-ms" = {};
  };
}
