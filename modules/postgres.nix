{
  lib,
  config,
  pkgs,
  ...
}: {
  options.services.postgresql = with lib; {
    userPasswords = mkOption {
      type = types.attrsOf types.path;
    };
  };

  config = let
    cfg = config.services.postgresql;
  in
    lib.mkIf cfg.enable {
      services.postgresql = {
        package = pkgs.postgresql_16;
        enableTCPIP = true;
        ensureUsers =
          map (db: {
            name = db;
            ensureDBOwnership = true;
          })
          cfg.ensureDatabases;

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
            ${builtins.concatStringsSep "\n" (lib.mapAttrsToList (
            name: passwordFile: ''
              password := trim(both from replace(pg_read_file('${passwordFile}'), E'\n', '''));
              EXECUTE format('ALTER ROLE "${name}" WITH PASSWORD '''%s''';', password);
            ''
          )
          cfg.userPasswords)}
          END $$;
        EOF
      '';
    };
}
