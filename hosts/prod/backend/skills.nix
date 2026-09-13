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
        itf-binary-range = {
          subtask_id = "39e59e0c-d2dd-40d0-b4dd-77e9d76e792c";
          task_id = "c50bffce-b8b3-4e33-9a40-3409c44f9b35";
          type = "multiple_choice";
        };
        itf-boundary-transfer = {
          subtask_id = "03909119-09f6-4321-ac6a-9f2a45864e18";
          task_id = "c50bffce-b8b3-4e33-9a40-3409c44f9b35";
          type = "multiple_choice";
        };
        itf-dns-transfer = {
          subtask_id = "4f75fb4e-3f27-4759-b43b-486f84d0e7b0";
          task_id = "c50bffce-b8b3-4e33-9a40-3409c44f9b35";
          type = "multiple_choice";
        };
        itf-evidence-transfer = {
          subtask_id = "b19cee0b-b240-4028-bec7-bbf1faa0f991";
          task_id = "c50bffce-b8b3-4e33-9a40-3409c44f9b35";
          type = "matching";
        };
        itf-files-transfer = {
          subtask_id = "8f6da2c7-4097-4003-ba44-62b08ae31891";
          task_id = "c50bffce-b8b3-4e33-9a40-3409c44f9b35";
          type = "matching";
        };
        itf-http-transfer = {
          subtask_id = "cef0ff34-d61a-442b-a5c7-5ae5c99f3586";
          task_id = "c50bffce-b8b3-4e33-9a40-3409c44f9b35";
          type = "matching";
        };
        itf-https-transfer = {
          subtask_id = "73a002a7-f1e5-408d-91ff-114e5839d19a";
          task_id = "c50bffce-b8b3-4e33-9a40-3409c44f9b35";
          type = "multiple_choice";
        };
        itf-image-budget = {
          subtask_id = "7f04c298-0a03-4e88-b7fe-a41b9eb6147e";
          task_id = "c50bffce-b8b3-4e33-9a40-3409c44f9b35";
          type = "multiple_choice";
        };
        itf-loop-transfer = {
          subtask_id = "5107e61b-d097-43bd-a4ed-1c8e83e436f9";
          task_id = "c50bffce-b8b3-4e33-9a40-3409c44f9b35";
          type = "multiple_choice";
        };
        itf-permission-transfer = {
          subtask_id = "b55bf8f5-747c-4cf2-89ae-686205ce8602";
          task_id = "c50bffce-b8b3-4e33-9a40-3409c44f9b35";
          type = "multiple_choice";
        };
        itf-power-loss-transfer = {
          subtask_id = "f0883332-3a94-4543-8ff3-46040eb5922e";
          task_id = "c50bffce-b8b3-4e33-9a40-3409c44f9b35";
          type = "multiple_choice";
        };
        itf-project-generator-review = {
          subtask_id = "a7b85da8-2119-49a3-943d-30f42b0125dc";
          task_id = "c50bffce-b8b3-4e33-9a40-3409c44f9b35";
          type = "multiple_choice";
        };
        itf-project-handover = {
          subtask_id = "25d1a5de-e2ed-45c7-99aa-e5f2326c1465";
          task_id = "c50bffce-b8b3-4e33-9a40-3409c44f9b35";
          type = "matching";
        };
        itf-project-recovery-review = {
          subtask_id = "ce452f02-3e96-49e2-8137-d4dbf3b7866b";
          task_id = "c50bffce-b8b3-4e33-9a40-3409c44f9b35";
          type = "multiple_choice";
        };
        itf-recover-transfer = {
          subtask_id = "8b49e8d6-735c-413c-bf2c-27600a75e495";
          task_id = "c50bffce-b8b3-4e33-9a40-3409c44f9b35";
          type = "multiple_choice";
        };
        itf-resource-diagnosis = {
          subtask_id = "2d0a15b9-a8be-4e49-b22e-049b19faf572";
          task_id = "c50bffce-b8b3-4e33-9a40-3409c44f9b35";
          type = "multiple_choice";
        };
        itf-safe-recovery = {
          subtask_id = "2fd365b0-ee1b-4520-bdd0-2525119915ce";
          task_id = "c50bffce-b8b3-4e33-9a40-3409c44f9b35";
          type = "multiple_choice";
        };
        itf-same-bytes = {
          subtask_id = "7b0aacfa-5257-4154-9324-055ff7abec8a";
          task_id = "c50bffce-b8b3-4e33-9a40-3409c44f9b35";
          type = "multiple_choice";
        };
        itf-sensor-transfer = {
          subtask_id = "404ad437-59a9-4ef2-b963-a7d24ef7d84b";
          task_id = "c50bffce-b8b3-4e33-9a40-3409c44f9b35";
          type = "matching";
        };
        itf-sequence-transfer = {
          subtask_id = "cb77b703-17fe-4049-a3ca-6615da1a6c15";
          task_id = "c50bffce-b8b3-4e33-9a40-3409c44f9b35";
          type = "multiple_choice";
        };
        itf-smallest-test = {
          subtask_id = "67809853-6657-4bde-b318-0b3f5875c03f";
          task_id = "c50bffce-b8b3-4e33-9a40-3409c44f9b35";
          type = "multiple_choice";
        };
        itf-ticket-machine = {
          subtask_id = "d56d4dd2-d9d9-4ea3-a964-0cf30b58ae2f";
          task_id = "c50bffce-b8b3-4e33-9a40-3409c44f9b35";
          type = "multiple_choice";
        };
        itf-transport-transfer = {
          subtask_id = "da4a9f7f-7cce-4b43-9a5c-905f0ff1b486";
          task_id = "c50bffce-b8b3-4e33-9a40-3409c44f9b35";
          type = "matching";
        };
        itf-wifi-transfer = {
          subtask_id = "6d35fc61-9814-4d39-a977-7c4b55dcb336";
          task_id = "c50bffce-b8b3-4e33-9a40-3409c44f9b35";
          type = "multiple_choice";
        };
        loops-code = {
          subtask_id = "9e4572bf-5d0a-4f68-80aa-38a837d556e0";
          task_id = "ddf71be4-f432-46d5-9cf1-f87e04e4d312";
          type = "coding";
        };
        loops-match = {
          subtask_id = "f3c393d7-8c1c-4151-8322-94cc0607d892";
          task_id = "ddf71be4-f432-46d5-9cf1-f87e04e4d312";
          type = "matching";
        };
        loops-predict = {
          subtask_id = "51f75114-b718-451d-a2f9-796376661280";
          task_id = "ddf71be4-f432-46d5-9cf1-f87e04e4d312";
          type = "multiple_choice";
        };
        percent-discount = {
          subtask_id = "4f13316d-f014-4fd0-abee-24eaf1186a1b";
          task_id = "a7460530-2ce7-415e-afc2-05a4124558b1";
          type = "multiple_choice";
        };
        percent-double-discount = {
          subtask_id = "7e5f7645-42c2-4e4d-a400-d2b6d1da9a3b";
          task_id = "a7460530-2ce7-415e-afc2-05a4124558b1";
          type = "multiple_choice";
        };
        percent-pairs = {
          subtask_id = "edb73b17-0bdd-496b-a1f2-81ee3605c813";
          task_id = "a7460530-2ce7-415e-afc2-05a4124558b1";
          type = "matching";
        };
        percent-transfer = {
          subtask_id = "2484a2b3-296e-432e-aef0-a7000f7a166d";
          task_id = "a7460530-2ce7-415e-afc2-05a4124558b1";
          type = "multiple_choice";
        };
        python-basket-code = {
          subtask_id = "13f66a48-9f74-40bc-afda-35718bb91a82";
          task_id = "e0de5382-47a2-4752-87e6-bbef2b5f4030";
          type = "coding";
        };
        python-condition-predict = {
          subtask_id = "6c67de36-3493-4fe5-9664-635809129217";
          task_id = "e0de5382-47a2-4752-87e6-bbef2b5f4030";
          type = "multiple_choice";
        };
        python-loop-trace = {
          subtask_id = "34f2b89f-3b1d-442c-a9e6-40da41c9dbf6";
          task_id = "e0de5382-47a2-4752-87e6-bbef2b5f4030";
          type = "multiple_choice";
        };
        python-order-total-code = {
          subtask_id = "79d4292d-20a1-47fd-84ec-34ccae88ca58";
          task_id = "e0de5382-47a2-4752-87e6-bbef2b5f4030";
          type = "coding";
        };
        python-shipping-code = {
          subtask_id = "e4ebc33e-7d03-4db5-b02b-79aa899c84d8";
          task_id = "e0de5382-47a2-4752-87e6-bbef2b5f4030";
          type = "coding";
        };
        python-sum-code = {
          subtask_id = "f113050c-27ce-4b1d-8309-d74f2795bab7";
          task_id = "e0de5382-47a2-4752-87e6-bbef2b5f4030";
          type = "coding";
        };
        python-values-match = {
          subtask_id = "ae4f8f0a-2b59-44ce-9e45-c6c1b165292e";
          task_id = "e0de5382-47a2-4752-87e6-bbef2b5f4030";
          type = "matching";
        };
        python-values-predict = {
          subtask_id = "af281b72-ca7a-4b37-ade0-a84ba1e29f17";
          task_id = "e0de5382-47a2-4752-87e6-bbef2b5f4030";
          type = "multiple_choice";
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
