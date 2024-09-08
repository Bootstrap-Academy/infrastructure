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

      systemd.services.postgresql = let
        escape = builtins.replaceStrings [":"] ["-"];
        passwordFileName = name: "user-password-${escape name}";
      in {
        serviceConfig.LoadCredential = lib.mapAttrsToList (name: passwordFile: "${passwordFileName name}:${passwordFile}") cfg.userPasswords;
        postStart = lib.mkIf (cfg.userPasswords != {}) (lib.mkAfter ''
          $PSQL -tA <<'EOF'
            DO $$
            DECLARE password TEXT;
            BEGIN
              ${builtins.concatStringsSep "\n" (lib.mapAttrsToList (
              name: _: ''
                password := trim(both from replace(pg_read_file('/run/credentials/postgresql.service/${passwordFileName name}'), E'\n', '''));
                EXECUTE format('ALTER ROLE "${name}" WITH PASSWORD '''%s''';', password);
              ''
            )
            cfg.userPasswords)}
            END $$;
          EOF
        '');
      };

      environment.persistence = lib.mkIf config.filesystems.defaultLayout {
        "/persistent/data".directories = ["/var/lib/postgresql"];
      };
    };
}
