{config, ...}: {
  academy.backend.microservices.shop = {
    port = 8002;
    database.passwordFile = config.sops.secrets."academy-backend/database/passwords/academy-shop".path;
    redis.database = 2;
    container = {
      image = "shop-ms:latest";
      environmentFiles = [config.sops.secrets."academy-backend/microservices/shop-ms".path];
      environment = {
        PAYPAL_BASE_URL = "https://api.paypal.com";
        PAYPAL_CLIENT_ID = "ATyoxdWxm36bTHFypQ2lVOwDQc4lKr0CkQs6NO03HfzFjnnM-6RIre6_ycFFQDP1Iez6zVxEe6o2FHu7";

        INVOICE_TEST = "False";
      };
    };
  };

  sops.secrets = {
    "academy-backend/database/passwords/academy-shop".owner = "postgres";
    "academy-backend/microservices/shop-ms" = {};
  };
}
