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
    database.passwordFile = config.sops.secrets."academy-backend/database/passwords/academy-jobs".path;
    redis.database = 3;
  };

  academy.backend.jobs = {
    enable = true;
    environmentFiles =
      config.academy.backend.common.environmentFiles
      ++ [config.sops.secrets."academy-backend/microservices/jobs-ms".path];
    settings =
      config.academy.backend.common.environment
      // {
        PORT = toString config.academy.backend.microservices.${ms}.port;
        ROOT_PATH = "/${ms}";
        REDIS_URL = config.academy.backend.common.environment."${lib.toUpper ms}_REDIS_URL";
        PUBLIC_BASE_URL = "https://${config.academy.backend.domain}/${ms}";
      };
  };

  sops.secrets = {
    "academy-backend/database/passwords/academy-jobs".owner = "postgres";
    "academy-backend/microservices/jobs-ms" = {};
  };
}
