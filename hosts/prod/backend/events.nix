{
  config,
  lib,
  events-ms,
  ...
}:
let
  ms = "events";
in
{
  imports = [ events-ms.nixosModules.default ];

  academy.backend.microservices.events = {
    port = 8004;
    database = { };
    redis.database = 4;
  };

  academy.backend.events = {
    enable = true;
    environmentFiles = config.academy.backend.common.environmentFiles ++ [
      config.sops.templates."academy-backend/events-ms".path
    ];
    settings = config.academy.backend.common.environment // {
      PORT = toString config.academy.backend.microservices.${ms}.port;
      ROOT_PATH = "/${ms}";
      REDIS_URL = config.academy.backend.common.environment."${lib.toUpper ms}_REDIS_URL";
      PUBLIC_BASE_URL = "https://${config.academy.backend.domain}/${ms}";
      DATABASE_URL = "postgresql+asyncpg://academy-${ms}@/academy-${ms}?host=/run/postgresql";

      EVENT_FEE = "0.3";

      WEBINAR_REGISTRATION_URL = "${config.academy.backend.frontend}/webinars/WEBINAR_ID/register";
      EVENT_CANCEL_URL = "${config.academy.backend.frontend}/calendar/EVENT_ID/cancel";

      EVENT_URL = "${config.academy.backend.frontend}/calendar";
    };
  };

  sops = {
    secrets = {
      "academy-backend/events-ms/sentry-dsn" = { };
      "academy-backend/events-ms/calendar-secret" = { };
    };
    templates."academy-backend/events-ms".content = ''
      SENTRY_DSN=${config.sops.placeholder."academy-backend/events-ms/sentry-dsn"}
      CALENDAR_SECRET=${config.sops.placeholder."academy-backend/events-ms/calendar-secret"}
    '';
  };
}
