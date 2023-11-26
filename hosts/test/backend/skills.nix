{config, ...}: let
  lecturesDir = "/var/www/lectures";
in {
  academy.backend.microservices.skills = {
    port = 8001;
    database.passwordFile = config.sops.secrets."academy-backend/database/passwords/academy-skills".path;
    redis.database = 1;
    container = {
      image = "skills-ms:develop";
      environmentFiles = [config.sops.secrets."academy-backend/microservices/skills-ms".path];
      environment = {
        LECTURE_XP = "10";

        PUBLIC_BASE_URL = "https://${config.academy.backend.domain}/skills";
        MP4_LECTURES = lecturesDir;
      };
    };
  };

  system.activationScripts.createLecturesDir = ''
    mkdir -p ${lecturesDir}
  '';

  sops.secrets = {
    "academy-backend/database/passwords/academy-skills".owner = "postgres";
    "academy-backend/microservices/skills-ms" = {};
  };
}
