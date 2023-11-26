{config, ...}: {
  academy.backend.microservices.shop = {
    port = 8002;
    database.passwordFile = config.sops.secrets."academy-backend/database/passwords/academy-shop".path;
    redis.database = 2;
    container = {
      image = "shop-ms:develop";
      environmentFiles = [config.sops.secrets."academy-backend/microservices/shop-ms".path];
      environment = {
        PAYPAL_BASE_URL = "https://api.sandbox.paypal.com";
        PAYPAL_CLIENT_ID = "AY8tdE7PPpUOVbURYdFvrqsisOiJpggHWnNYphRQjbDPCoPcD3z7XUU067hZ6kf4cH82GwQrAkJnhcqn";

        INVOICE_TEST = "True";
      };
    };
  };

  sops.secrets = {
    "academy-backend/database/passwords/academy-shop".owner = "postgres";
    "academy-backend/microservices/shop-ms" = {};
  };
}
