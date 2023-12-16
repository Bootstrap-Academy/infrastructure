{config, ...}: {
  academy.backend.microservices.events = {
    port = 8004;
    database.passwordFile = config.sops.secrets."academy-backend/database/passwords/academy-events".path;
    redis.database = 4;
    container = {
      image = "events-ms:latest";
      environmentFiles = [config.sops.secrets."academy-backend/microservices/events-ms".path];
      environment = {
        EVENT_FEE = "0.3";

        WEBINAR_REGISTRATION_URL = "${config.academy.backend.frontend}/webinars/WEBINAR_ID/register";
        EVENT_CANCEL_URL = "${config.academy.backend.frontend}/calendar/EVENT_ID/cancel";

        EVENT_URL = "${config.academy.backend.frontend}/calendar";
      };
    };
  };

  sops.secrets = {
    "academy-backend/database/passwords/academy-events".owner = "postgres";
    "academy-backend/microservices/events-ms" = {};
  };
}
