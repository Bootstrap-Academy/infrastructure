{ config, pkgs, ... }:
let
  ports = {
    mariadb = 3306;
    redis = 63791;
  };
  baseEnv = {
    LOG_LEVEL = "INFO";
    PYCORD_LOG_LEVEL = "ERROR";

    DB_DRIVER = "mysql+aiomysql";
    DB_HOST = "127.0.0.1";
    DB_PORT = toString ports.mariadb;
    POOL_RECYCLE = "300";
    POOL_SIZE = "20";
    MAX_OVERFLOW = "100";
    SQL_SHOW_STATEMENTS = "False";

    OWNER_ID = "370876111992913922";
    DISABLED_COGS = "AdventOfCode,RedditCog";

    AOC_REFRESH_INTERVAL = "300";

    REDIS_HOST = "127.0.0.1";
    REDIS_PORT = toString ports.redis;

    CACHE_TTL = "28800";
    RESPONSE_LINK_TTL = "7200";
    PAGINATION_TTL = "7200";

    REPLY = "True";
    MENTION_AUTHOR = "True";

    DISABLE_PAGINATION = "False";

    VOICE_CHANNEL_NAMES = "elements";
  };
in
{
  virtualisation.oci-containers.containers = {
    morpheushelper = config.dockerImages.morpheushelper.mkContainer {
      extraOptions = [
        "--rm=false"
        "--restart=always"
        "--network=host"
        "--no-healthcheck"
      ];
      volumes = [ "${./config.yml}:/app/config.yml:ro" ];
      environmentFiles = [ config.sops.templates."morpheushelper/env".path ];
      environment = baseEnv // {
        DB_DATABASE = "morpheushelper";
        DB_USERNAME = "morpheushelper";
        REDIS_DB = "0";
      };
    };
  };

  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    settings.mysqld = {
      bind_address = "127.0.0.1";
      port = ports.mariadb;
      max_allowed_packet = "256M";
      max_connections = "400";
    };
    ensureDatabases = [ "morpheushelper" ];
    ensureUsers = [
      {
        name = "morpheushelper";
        ensurePermissions."morpheushelper.*" = "ALL PRIVILEGES";
      }
    ];
  };

  services.redis.servers.morpheushelper = {
    enable = true;
    bind = "127.0.0.1";
    port = ports.redis;
    save = [ ];
    settings.protected-mode = "no";
  };

  environment.persistence."/persistent/data".directories = [ "/var/lib/mysql" ];

  backup.exclude = [ "/var/lib/mysql" ];
  backup.prepare = "${config.services.mysql.package}/bin/mysqldump --all-databases > mysql-dump.sql";

  sops = {
    secrets = {
      "morpheushelper/discord-token" = { };
      "morpheushelper/database-password" = { };
      "morpheushelper/aoc-session" = { };
      "morpheushelper/github-token" = { };
    };
    templates."morpheushelper/env".content = ''
      TOKEN=${config.sops.placeholder."morpheushelper/discord-token"}
      DB_PASSWORD=${config.sops.placeholder."morpheushelper/database-password"}
      AOC_SESSION=${config.sops.placeholder."morpheushelper/aoc-session"}
      GITHUB_TOKEN=${config.sops.placeholder."morpheushelper/github-token"}
    '';
  };
}
