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

        MP4_LECTURES = lecturesDir;
        STREAM_CHUNK_SIZE = toString (4 * 1024 * 1024); # bytes
        STREAM_TOKEN_TTL = toString (8 * 60 * 60); # seconds
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
