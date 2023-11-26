{config, ...}: let
  port = 8001;
  lecturesDir = "/var/www/lectures";
in {
  academy.backend.microservices.skills = {
    inherit port;
    database.passwordFile = config.sops.secrets."academy-backend/database/passwords/academy-skills".path;
    container = {
      image = "skills-ms:develop";
      environmentFiles = [config.sops.secrets."academy-backend/microservices/skills-ms".path];
      environment = {
        PORT = toString port;
        ROOT_PATH = "/skills";

        LECTURE_XP = "10";

        PUBLIC_BASE_URL = "https://${config.academy.backend.domain}/skills";
        MP4_LECTURES = lecturesDir;

        REDIS_URL = config.academy.backend.common.environment.SKILLS_REDIS_URL;
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
