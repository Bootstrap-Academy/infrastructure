{
  pkgs,
  lib,
  config,
  ...
}: {
  config = let
    cfg = config.academy.backend;
    microservices = builtins.filter (ms: cfg.microservices.${ms}.database != null) (builtins.attrNames cfg.microservices);
    dbName = ms: "academy-${ms}";
  in
    lib.mkIf cfg.enable {
      services.postgresql = {
        enable = true;
        package = pkgs.postgresql_16;
        enableTCPIP = true;
        ensureDatabases = map dbName microservices;
        ensureUsers =
          map (ms: {
            name = dbName ms;
            ensureDBOwnership = true;
          })
          microservices;
        authentication = lib.mkForce ''
          local all all peer
          host all all all scram-sha-256
        '';
      };

      systemd.services.postgresql.postStart = lib.mkAfter ''
        $PSQL -tA <<'EOF'
          DO $$
          DECLARE password TEXT;
          BEGIN
            ${builtins.concatStringsSep "\n" (map (ms: ''
            password := trim(both from replace(pg_read_file('${cfg.microservices.${ms}.database.passwordFile}'), E'\n', '''));
            EXECUTE format('ALTER ROLE "${dbName ms}" WITH PASSWORD '''%s''';', password);
          '')
          microservices)}
          END $$;
        EOF
      '';
    };
}
