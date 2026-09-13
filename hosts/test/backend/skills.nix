{
  config,
  lib,
  skills-ms-develop,
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
  imports = [ skills-ms-develop.nixosModules.default ];

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

      COURSES = "${skills-ms-develop.packages.${system}.courses}";

      ROOMS_ENABLED = "true";
      CHALLENGES_URL = "http://127.0.0.1:8005";
      LEARNING_ROOMS_EXERCISE_REFS = builtins.toJSON {
        itf-binary-range = {
          type = "multiple_choice";
          task_id = "27027c3e-3c99-4ce9-b170-22fc7de029d0";
          subtask_id = "1d2dc356-a5fb-4a90-841b-75f024310de2";
        };
        itf-boundary-transfer = {
          type = "multiple_choice";
          task_id = "27027c3e-3c99-4ce9-b170-22fc7de029d0";
          subtask_id = "fbe0bc36-69f3-4f48-8b8f-8c766cf973d7";
        };
        itf-dns-transfer = {
          type = "multiple_choice";
          task_id = "27027c3e-3c99-4ce9-b170-22fc7de029d0";
          subtask_id = "fa04b0ac-9b9c-4a09-86c3-27747ef7709e";
        };
        itf-evidence-transfer = {
          type = "matching";
          task_id = "27027c3e-3c99-4ce9-b170-22fc7de029d0";
          subtask_id = "ee1f44c3-ebdb-49f1-9e22-3492ec6c47f0";
        };
        itf-files-transfer = {
          type = "matching";
          task_id = "27027c3e-3c99-4ce9-b170-22fc7de029d0";
          subtask_id = "9519992a-ebd0-44ce-a86e-342d6364c071";
        };
        itf-http-transfer = {
          type = "matching";
          task_id = "27027c3e-3c99-4ce9-b170-22fc7de029d0";
          subtask_id = "2a2b17a1-28c4-487a-a6ab-73712f8ba224";
        };
        itf-https-transfer = {
          type = "multiple_choice";
          task_id = "27027c3e-3c99-4ce9-b170-22fc7de029d0";
          subtask_id = "de4776aa-40c1-44f4-a42b-af5a6cfff01d";
        };
        itf-image-budget = {
          type = "multiple_choice";
          task_id = "27027c3e-3c99-4ce9-b170-22fc7de029d0";
          subtask_id = "1e16c769-225e-4a47-bf68-498155669723";
        };
        itf-loop-transfer = {
          type = "multiple_choice";
          task_id = "27027c3e-3c99-4ce9-b170-22fc7de029d0";
          subtask_id = "a235f145-5d2a-4415-a654-7c09de3bf178";
        };
        itf-permission-transfer = {
          type = "multiple_choice";
          task_id = "27027c3e-3c99-4ce9-b170-22fc7de029d0";
          subtask_id = "be08d4e2-eb13-48f6-9172-c692e6982da3";
        };
        itf-power-loss-transfer = {
          type = "multiple_choice";
          task_id = "27027c3e-3c99-4ce9-b170-22fc7de029d0";
          subtask_id = "1dd3b2ec-c01f-4fcb-bbd1-02cf6ff01890";
        };
        itf-project-generator-review = {
          type = "multiple_choice";
          task_id = "27027c3e-3c99-4ce9-b170-22fc7de029d0";
          subtask_id = "3015fe0e-ea42-4e09-bec8-658bd06170e5";
        };
        itf-project-handover = {
          type = "matching";
          task_id = "27027c3e-3c99-4ce9-b170-22fc7de029d0";
          subtask_id = "a5c01838-15c3-4f81-8865-6fa139c546a3";
        };
        itf-project-recovery-review = {
          type = "multiple_choice";
          task_id = "27027c3e-3c99-4ce9-b170-22fc7de029d0";
          subtask_id = "298715ff-38af-4c82-873e-548f97a38339";
        };
        itf-recover-transfer = {
          type = "multiple_choice";
          task_id = "27027c3e-3c99-4ce9-b170-22fc7de029d0";
          subtask_id = "31bc2a95-afc3-4ce2-9144-047929bc0cb9";
        };
        itf-resource-diagnosis = {
          type = "multiple_choice";
          task_id = "27027c3e-3c99-4ce9-b170-22fc7de029d0";
          subtask_id = "756de3d3-e6cd-4251-8bd5-21f1f779281e";
        };
        itf-safe-recovery = {
          type = "multiple_choice";
          task_id = "27027c3e-3c99-4ce9-b170-22fc7de029d0";
          subtask_id = "14852930-974c-43d5-972c-3b79c861255c";
        };
        itf-same-bytes = {
          type = "multiple_choice";
          task_id = "27027c3e-3c99-4ce9-b170-22fc7de029d0";
          subtask_id = "ed93d926-a960-439a-99e7-220200fbcce7";
        };
        itf-sensor-transfer = {
          type = "matching";
          task_id = "27027c3e-3c99-4ce9-b170-22fc7de029d0";
          subtask_id = "e8511575-3984-4f3f-bb4c-f8c0865f0b0d";
        };
        itf-sequence-transfer = {
          type = "multiple_choice";
          task_id = "27027c3e-3c99-4ce9-b170-22fc7de029d0";
          subtask_id = "50feb1d6-30f4-40e5-9a9c-856b62611fcd";
        };
        itf-smallest-test = {
          type = "multiple_choice";
          task_id = "27027c3e-3c99-4ce9-b170-22fc7de029d0";
          subtask_id = "85121b30-b82a-457e-bc72-218c7bb515d9";
        };
        itf-ticket-machine = {
          type = "multiple_choice";
          task_id = "27027c3e-3c99-4ce9-b170-22fc7de029d0";
          subtask_id = "b5938ac8-b3e7-459e-8ad1-79921c12fde5";
        };
        itf-transport-transfer = {
          type = "matching";
          task_id = "27027c3e-3c99-4ce9-b170-22fc7de029d0";
          subtask_id = "6770e3ba-23db-43c9-a188-b69c84945837";
        };
        itf-wifi-transfer = {
          type = "multiple_choice";
          task_id = "27027c3e-3c99-4ce9-b170-22fc7de029d0";
          subtask_id = "2cb5d50a-bc62-42d6-be21-095e19825f8c";
        };
        loops-code = {
          type = "coding";
          task_id = "94338c50-72dd-4c33-8f29-0e50bd33f328";
          subtask_id = "753c85ca-caf4-41fd-a927-2925fc73b649";
        };
        loops-match = {
          type = "matching";
          task_id = "94338c50-72dd-4c33-8f29-0e50bd33f328";
          subtask_id = "5bcb585f-302b-4265-b2f5-4a255f872394";
        };
        loops-predict = {
          type = "multiple_choice";
          task_id = "94338c50-72dd-4c33-8f29-0e50bd33f328";
          subtask_id = "5184dd0b-8880-410a-ae18-34b2c014f70c";
        };
        percent-discount = {
          type = "multiple_choice";
          task_id = "3224af44-bfd7-4274-93bb-2464452c35c3";
          subtask_id = "6622ae62-8d14-4b35-a6f9-1f2860694587";
        };
        percent-double-discount = {
          type = "multiple_choice";
          task_id = "3224af44-bfd7-4274-93bb-2464452c35c3";
          subtask_id = "36e4072b-0cb8-4627-b1f1-68eea8c3dbb4";
        };
        percent-pairs = {
          type = "matching";
          task_id = "3224af44-bfd7-4274-93bb-2464452c35c3";
          subtask_id = "65a53338-888d-4c71-af26-e625ad8e3f6f";
        };
        percent-transfer = {
          type = "multiple_choice";
          task_id = "3224af44-bfd7-4274-93bb-2464452c35c3";
          subtask_id = "843c9c3d-677b-4518-986f-b31b83f6d190";
        };
        python-basket-code = {
          type = "coding";
          task_id = "9a6a1bf5-4080-4e13-a71d-4d8c8163dae4";
          subtask_id = "d09c8a96-95f4-4adb-a9a6-10a10fcea3c5";
        };
        python-condition-predict = {
          type = "multiple_choice";
          task_id = "9a6a1bf5-4080-4e13-a71d-4d8c8163dae4";
          subtask_id = "c7456ecf-acba-44ba-a5ee-97592aa5d85d";
        };
        python-loop-trace = {
          type = "multiple_choice";
          task_id = "9a6a1bf5-4080-4e13-a71d-4d8c8163dae4";
          subtask_id = "2283017c-dbf1-47d4-b594-fe79bc203b04";
        };
        python-order-total-code = {
          type = "coding";
          task_id = "9a6a1bf5-4080-4e13-a71d-4d8c8163dae4";
          subtask_id = "da9cdff5-e0b0-46a3-8d37-4e301b6d674d";
        };
        python-shipping-code = {
          type = "coding";
          task_id = "9a6a1bf5-4080-4e13-a71d-4d8c8163dae4";
          subtask_id = "2782ea52-51fb-414f-8984-04ca2f4c21c2";
        };
        python-sum-code = {
          type = "coding";
          task_id = "9a6a1bf5-4080-4e13-a71d-4d8c8163dae4";
          subtask_id = "6aad85b2-dab2-42f4-8976-bcc953b4949a";
        };
        python-values-match = {
          type = "matching";
          task_id = "9a6a1bf5-4080-4e13-a71d-4d8c8163dae4";
          subtask_id = "d03412a9-355f-4d85-96ef-fca0b6f596ee";
        };
        python-values-predict = {
          type = "multiple_choice";
          task_id = "9a6a1bf5-4080-4e13-a71d-4d8c8163dae4";
          subtask_id = "2b830474-7af6-40ff-b55b-df3130c7a5d5";
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
