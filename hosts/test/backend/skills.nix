{
  config,
  lib,
  skills-ms-develop,
  pkgs,
  ...
}: let
  ms = "skills";
in {
  imports = [skills-ms-develop.nixosModules.default];

  academy.backend.microservices.skills = {
    port = 8001;
    database.passwordFile = config.sops.secrets."academy-backend/database/passwords/academy-skills".path;
    redis.database = 1;
  };

  academy.backend.skills = {
    enable = true;
    environmentFiles =
      config.academy.backend.common.environmentFiles
      ++ [config.sops.secrets."academy-backend/microservices/skills-ms".path];
    settings =
      config.academy.backend.common.environment
      // {
        PORT = toString config.academy.backend.microservices.${ms}.port;
        ROOT_PATH = "/${ms}";
        REDIS_URL = config.academy.backend.common.environment."${lib.toUpper ms}_REDIS_URL";
        PUBLIC_BASE_URL = "https://${config.academy.backend.domain}/${ms}";

        COURSES = toString skills-ms-develop.packages.${pkgs.system}.courses;

        LECTURE_XP = "10";
        MP4_LECTURES = "/mnt/lectures";
        STREAM_CHUNK_SIZE = toString (4 * 1024 * 1024); # bytes
        STREAM_TOKEN_TTL = toString (8 * 60 * 60); # seconds
      };
  };

  sops.secrets = {
    "academy-backend/database/passwords/academy-skills".owner = "postgres";
    "academy-backend/microservices/skills-ms" = {};
  };
}
