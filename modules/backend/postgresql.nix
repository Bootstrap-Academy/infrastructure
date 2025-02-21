{ lib, config, ... }:
{
  config =
    let
      cfg = config.academy.backend;
      microservices = builtins.filter (ms: cfg.microservices.${ms}.database != null) (
        builtins.attrNames cfg.microservices
      );
      dbName = ms: "academy-${ms}";
    in
    lib.mkIf cfg.enable {
      services.postgresql = {
        enable = true;
        ensureDatabases = map dbName microservices;
        userPasswords = builtins.listToAttrs (
          map (ms: {
            name = dbName ms;
            value = cfg.microservices.${ms}.database.passwordFile;
          }) (builtins.filter (ms: cfg.microservices.${ms}.database.passwordFile != null) microservices)
        );
      };
    };
}
