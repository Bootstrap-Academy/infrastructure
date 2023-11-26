{config, ...}: {
  academy.backend.microservices.jobs = {
    port = 8003;
    database.passwordFile = config.sops.secrets."academy-backend/database/passwords/academy-jobs".path;
    redis.database = 3;
    container = {
      image = "jobs-ms:develop";
      environmentFiles = [config.sops.secrets."academy-backend/microservices/jobs-ms".path];
      environment = {};
    };
  };

  sops.secrets = {
    "academy-backend/database/passwords/academy-jobs".owner = "postgres";
    "academy-backend/microservices/jobs-ms" = {};
  };
}
