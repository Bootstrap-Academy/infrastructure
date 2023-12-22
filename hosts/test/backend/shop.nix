{
  config,
  lib,
  shop-ms-develop,
  ...
}: let
  ms = "shop";
in {
  imports = [shop-ms-develop.nixosModules.default];

  academy.backend.microservices.shop = {
    port = 8002;
    database = {};
    redis.database = 2;
  };

  academy.backend.shop = {
    enable = true;
    environmentFiles =
      config.academy.backend.common.environmentFiles
      ++ [config.sops.secrets."academy-backend/microservices/shop-ms".path];
    settings =
      config.academy.backend.common.environment
      // {
        PORT = toString config.academy.backend.microservices.${ms}.port;
        ROOT_PATH = "/${ms}";
        REDIS_URL = config.academy.backend.common.environment."${lib.toUpper ms}_REDIS_URL";
        PUBLIC_BASE_URL = "https://${config.academy.backend.domain}/${ms}";
        DATABASE_URL = "postgresql+asyncpg://academy-${ms}@/academy-${ms}?host=/run/postgresql";

        PAYPAL_BASE_URL = "https://api.sandbox.paypal.com";
        PAYPAL_CLIENT_ID = "AY8tdE7PPpUOVbURYdFvrqsisOiJpggHWnNYphRQjbDPCoPcD3z7XUU067hZ6kf4cH82GwQrAkJnhcqn";

        INVOICE_TEST = "True";
      };
  };

  sops.secrets = {
    "academy-backend/microservices/shop-ms" = {};
  };
}
