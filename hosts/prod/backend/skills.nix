{
  config,
  lib,
  skills-ms,
  system,
  ...
}:

let
  ms = "skills";

  # the audiences this service talks to, plus its own for incoming tokens
  internalJwtSecrets = config.academy.backend.internalJwtSecrets.values;
  coursesPath = config.academy.backend.skills.settings.COURSES;
  coursesContext = builtins.getContext coursesPath;
  courseFiles = if builtins.pathExists coursesPath then builtins.readDir coursesPath else { };
in

{
  imports = [ skills-ms.nixosModules.default ];

  assertions = [
    {
      assertion = lib.any (path: path == coursesPath && (coursesContext.${path}.path or false)) (
        builtins.attrNames coursesContext
      );
      message = "Skills COURSES must retain its store-path reference in the deployment closure.";
    }
    {
      assertion = lib.any (name: lib.hasSuffix ".yml" name && courseFiles.${name} == "regular") (
        builtins.attrNames courseFiles
      );
      message = "Skills COURSES must contain course YAML definitions.";
    }
  ];

  academy.backend.microservices.skills = {
    port = 8001;
    database = { };
    redis.database = 1;
  };

  academy.backend.skills = {
    enable = true;
    sweepDeletedUsers = {
      enable = true;
      interval = "03:10";
    };
    environmentFiles = config.academy.backend.common.environmentFiles ++ [
      config.sops.templates."academy-backend/skills-ms".path
    ];
    settings = config.academy.backend.common.environment // {
      PORT = toString config.academy.backend.microservices.${ms}.port;
      ROOT_PATH = "/${ms}";
      REDIS_URL = config.academy.backend.common.environment."${lib.toUpper ms}_REDIS_URL";
      PUBLIC_BASE_URL = "https://${config.academy.backend.domain}/${ms}";
      DATABASE_URL = "postgresql+asyncpg://academy-${ms}@/academy-${ms}?host=/run/postgresql";

      COURSES = "${skills-ms.packages.${system}.courses}";

      ROOMS_ENABLED = "true";
      CHALLENGES_URL = "http://127.0.0.1:8005";
      LEARNING_ROOMS_EXERCISE_REFS = builtins.toJSON {
        loops-predict = {
          type = "multiple_choice";
          task_id = "ddf71be4-f432-46d5-9cf1-f87e04e4d312";
          subtask_id = "51f75114-b718-451d-a2f9-796376661280";
        };
        loops-match = {
          type = "matching";
          task_id = "ddf71be4-f432-46d5-9cf1-f87e04e4d312";
          subtask_id = "f3c393d7-8c1c-4151-8322-94cc0607d892";
        };
        loops-code = {
          type = "coding";
          task_id = "ddf71be4-f432-46d5-9cf1-f87e04e4d312";
          subtask_id = "9e4572bf-5d0a-4f68-80aa-38a837d556e0";
        };
      };

      LECTURE_XP = "10";
      MP4_LECTURES = "/mnt/lectures";
      STREAM_CHUNK_SIZE = toString (4 * 1024 * 1024); # bytes
      STREAM_TOKEN_TTL = toString (8 * 60 * 60); # seconds
    };
  };

  sops = {
    secrets = {
      "academy-backend/skills-ms/sentry-dsn" = { };
    };
    templates."academy-backend/skills-ms".content = ''
      SENTRY_DSN=${config.sops.placeholder."academy-backend/skills-ms/sentry-dsn"}
      INTERNAL_JWT_SECRET_AUTH=${internalJwtSecrets.auth}
      INTERNAL_JWT_SECRET_SHOP=${internalJwtSecrets.shop}
      INTERNAL_JWT_SECRET_SKILLS=${internalJwtSecrets.skills}
    '';
  };
}
