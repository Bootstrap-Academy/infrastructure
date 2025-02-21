{
  config,
  challenges-ms-develop,
  env,
  ...
}:
{
  imports = [ challenges-ms-develop.nixosModules.default ];

  academy.backend.microservices.challenges = {
    port = 8005;
    database = { };
    redis.database = 5;
  };

  academy.backend.challenges = {
    enable = true;
    RUST_LOG = "info,poem_ext,lib,entity,migration,challenges=trace";
    environmentFiles = [
      config.sops.templates."academy-backend/common".path
      config.sops.templates."academy-backend/challenges-ms".path
    ];
    settings = {
      internal_jwt_ttl = 10; # seconds
      cache_ttl = 300; # seconds

      database = {
        url = "postgres://academy-challenges@localhost/academy-challenges?host=/run/postgresql";
        connect_timeout = 5; # seconds
      };

      redis =
        builtins.mapAttrs (
          ms: { redis, ... }: "redis://127.0.0.1:6379/${toString redis.database}"
        ) config.academy.backend.microservices
        // {
          auth = "redis://127.0.0.1:6379/0";
          shop = "redis://127.0.0.1:6379/0";
        };

      services =
        builtins.mapAttrs (
          ms: { port, ... }: "http://127.0.0.1:${toString port}/"
        ) config.academy.backend.microservices
        // {
          auth = "http://127.0.0.1:8000/auth/";
          shop = "http://127.0.0.1:8000/shop/";
        };

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
        ban_days = [
          3
          7
          30
        ];
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
        sandkasten_url = "http://10.23.0.3:8000/";
        max_concurrency = 2;
        timeout = 10; # seconds
        hearts = 2;
        creator_coins = 10;
      };
    };
  };

  systemd.services.academy-challenges = {
    after = [
      "network-online.target"
      "postgresql.service"
    ];
    serviceConfig.Restart = "always";
  };

  sops = {
    secrets = {
      "academy-backend/challenges-ms/sentry-dsn" = { };
    };
    templates."academy-backend/challenges-ms".content = ''
      CHALLENGES__SENTRY__DSN=${config.sops.placeholder."academy-backend/challenges-ms/sentry-dsn"}
    '';
  };
}
