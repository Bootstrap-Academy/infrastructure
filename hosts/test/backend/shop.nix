{config, ...}: let
  port = 8002;
in {
  academy.backend.microservices.shop = {
    inherit port;
    database.passwordFile = config.sops.secrets."academy-backend/database/passwords/academy-shop".path;
    container = {
      image = "shop-ms:develop";
      environmentFiles = [config.sops.secrets."academy-backend/microservices/shop-ms".path];
      environment = {
        PORT = toString port;
        ROOT_PATH = "/shop";

        PAYPAL_BASE_URL = "https://api.sandbox.paypal.com";
        PAYPAL_CLIENT_ID = "AY8tdE7PPpUOVbURYdFvrqsisOiJpggHWnNYphRQjbDPCoPcD3z7XUU067hZ6kf4cH82GwQrAkJnhcqn";

        INVOICE_TEST = "True";

        REDIS_URL = config.academy.backend.common.environment.SHOP_REDIS_URL;
      };
    };
  };

  sops.secrets = {
    "academy-backend/database/passwords/academy-shop".owner = "postgres";
    "academy-backend/microservices/shop-ms" = {};
  };
}
