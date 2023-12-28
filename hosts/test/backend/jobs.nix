{
  config,
  lib,
  jobs-ms-develop,
  ...
}: let
  ms = "jobs";
in {
  imports = [jobs-ms-develop.nixosModules.default];

  academy.backend.microservices.jobs = {
    port = 8003;
    database = {};
    redis.database = 3;
  };

  academy.backend.jobs = {
    enable = true;
    environmentFiles =
      config.academy.backend.common.environmentFiles
      ++ [config.sops.templates."academy-backend/jobs-ms".path];
    settings =
      config.academy.backend.common.environment
      // {
        PORT = toString config.academy.backend.microservices.${ms}.port;
        ROOT_PATH = "/${ms}";
        REDIS_URL = config.academy.backend.common.environment."${lib.toUpper ms}_REDIS_URL";
        PUBLIC_BASE_URL = "https://${config.academy.backend.domain}/${ms}";
        DATABASE_URL = "postgresql+asyncpg://academy-${ms}@/academy-${ms}?host=/run/postgresql";
      };
  };

  sops = {
    secrets = {
      "academy-backend/jobs-ms/sentry-dsn" = {};
    };
    templates."academy-backend/jobs-ms".content = ''
      SENTRY_DSN=${config.sops.placeholder."academy-backend/jobs-ms/sentry-dsn"}
    '';
  };
}
