{
  config,
  challenges-ms-develop,
  env,
  ...
}: {
  imports = [challenges-ms-develop.nixosModules.default];

  academy.backend.microservices.challenges = {
    port = 8005;
    database.passwordFile = config.sops.secrets."academy-backend/database/passwords/academy-challenges".path;
    redis.database = 5;
  };

  academy.backend.challenges = {
    enable = true;
    RUST_LOG = "info,poem_ext,lib,entity,migration,challenges=trace";
    environmentFiles = [
      config.sops.secrets."academy-backend/microservices/common".path
      config.sops.secrets."academy-backend/microservices/challenges-ms".path
    ];
    settings = {
      internal_jwt_ttl = 10; # seconds
      cache_ttl = 10; # seconds

      database.connect_timeout = 5; # seconds

      redis = builtins.mapAttrs (ms: {redis, ...}: "redis://127.0.0.1:6379/${toString redis.database}") config.academy.backend.microservices;

      services = builtins.mapAttrs (ms: {port, ...}: "http://127.0.0.1:${toString port}/") config.academy.backend.microservices;

      challenges = {
        inherit (config.academy.backend.microservices.challenges) port;
        host = "127.0.0.1";
        server = "/challenges";
      };

      challenges.quizzes = {
        # min_level = 5;
        min_level = 0;
        max_xp = 5;
        max_coins = 0;
        max_fee = 1;
        ban_days = [3 7 30];
      };

      challenges.multiple_choice_questions = {
        timeout = 2; # seconds
        hearts = 1;
        creator_coins = 1;
      };

      challenges.questions = {
        timeout = 2; # seconds
        hearts = 1;
        creator_coins = 1;
      };

      challenges.matchings = {
        timeout = 2; # seconds
        hearts = 1;
        creator_coins = 1;
      };

      challenges.coding_challenges = {
        sandkasten_url = "http://${env.servers.sandkasten.net.private.ip4}:8000/";
        max_concurrency = 2;
        timeout = 10; # seconds
        hearts = 2;
        creator_coins = 10;
      };
    };
  };

  systemd.services.academy-challenges = {
    after = ["network-online.target" "postgresql.service"];
    serviceConfig.Restart = "always";
  };

  sops.secrets = {
    "academy-backend/database/passwords/academy-challenges".owner = "postgres";
    "academy-backend/microservices/challenges-ms" = {};
  };
}
