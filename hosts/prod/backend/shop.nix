{
  config,
  lib,
  shop-ms,
  ...
}: let
  ms = "shop";
in {
  imports = [shop-ms.nixosModules.default];

  academy.backend.microservices.shop = {
    port = 8002;
    database = {};
    redis.database = 2;
  };

  academy.backend.shop = {
    enable = true;
    environmentFiles =
      config.academy.backend.common.environmentFiles
      ++ [config.sops.templates."academy-backend/shop-ms".path];
    settings =
      config.academy.backend.common.environment
      // {
        PORT = toString config.academy.backend.microservices.${ms}.port;
        ROOT_PATH = "/${ms}";
        REDIS_URL = config.academy.backend.common.environment."${lib.toUpper ms}_REDIS_URL";
        PUBLIC_BASE_URL = "https://${config.academy.backend.domain}/${ms}";
        DATABASE_URL = "postgresql+asyncpg://academy-${ms}@/academy-${ms}?host=/run/postgresql";

        PAYPAL_BASE_URL = "https://api.paypal.com";
        PAYPAL_CLIENT_ID = "ATyoxdWxm36bTHFypQ2lVOwDQc4lKr0CkQs6NO03HfzFjnnM-6RIre6_ycFFQDP1Iez6zVxEe6o2FHu7";

        INVOICE_TEST = "False";
      };
  };

  sops = {
    secrets = {
      "academy-backend/shop-ms/sentry-dsn" = {};
      "academy-backend/shop-ms/paypal-secret" = {};
      "academy-backend/shop-ms/invoice-secret" = {};
    };
    templates."academy-backend/shop-ms".content = ''
      SENTRY_DSN=${config.sops.placeholder."academy-backend/shop-ms/sentry-dsn"}
      PAYPAL_SECRET=${config.sops.placeholder."academy-backend/shop-ms/paypal-secret"}
      INVOICE_SECRET=${config.sops.placeholder."academy-backend/shop-ms/invoice-secret"}
    '';
  };
}
