{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.postgresql;
  escape = lib.replaceStrings [ ":" ] [ "-" ];
  passwordFileName = name: "user-password-${escape name}";

  newPostgres = pkgs.postgresql_18;
  upgrading = newPostgres.psqlSchema != cfg.package.psqlSchema;

  postgres-upgrade = pkgs.writeScriptBin "postgres-upgrade" ''
    set -eux

    systemctl stop postgresql

    export NEWDATA="/var/lib/postgresql/${newPostgres.psqlSchema}"
    export NEWBIN="${newPostgres}/bin"

    export OLDDATA="${cfg.dataDir}"
    export OLDBIN="${cfg.finalPackage}/bin"

    install -d -m 0700 -o postgres -g postgres "$NEWDATA"
    cd "$NEWDATA"
    sudo -u postgres "$NEWBIN/initdb" -D "$NEWDATA" ${lib.escapeShellArgs cfg.initdbArgs}

    sudo -u postgres "$NEWBIN/pg_upgrade" \
      --old-datadir "$OLDDATA" --new-datadir "$NEWDATA" \
      --old-bindir "$OLDBIN" --new-bindir "$NEWBIN" \
      --clone \
      "$@"
  '';
in

{
  options.services.postgresql = {
    userPasswords = lib.mkOption { type = lib.types.attrsOf lib.types.path; };
  };

  config = lib.mkIf cfg.enable {
    services.postgresql = {
      package = pkgs.postgresql_18;
      enableTCPIP = true;
      ensureUsers = map (db: {
        name = db;
        ensureDBOwnership = true;
      }) cfg.ensureDatabases;

      authentication = lib.mkForce ''
        local all all peer
        host all all all scram-sha-256
      '';
    };

    systemd.services.postgresql.serviceConfig.LoadCredential = lib.mapAttrsToList (
      name: passwordFile: "${passwordFileName name}:${passwordFile}"
    ) cfg.userPasswords;
    systemd.services.postgresql-setup.script = lib.mkIf (cfg.userPasswords != { }) (
      lib.mkAfter ''
        psql -tA <<'EOF'
          DO $$
          DECLARE password TEXT;
          BEGIN
            ${lib.concatStringsSep "\n" (
              lib.mapAttrsToList (name: _: ''
                password := trim(both from replace(pg_read_file('/run/credentials/postgresql.service/${passwordFileName name}'), E'\n', '''));
                EXECUTE format('ALTER ROLE "${name}" WITH PASSWORD '''%s''';', password);
              '') cfg.userPasswords
            )}
          END $$;
        EOF
      ''
    );

    environment.systemPackages = lib.mkIf upgrading [ postgres-upgrade ];

    environment.persistence = lib.mkIf config.filesystems.defaultLayout {
      "/persistent/data".directories = [ "/var/lib/postgresql" ];
    };

    backup.exclude = [ "/var/lib/postgresql" ];
    backup.prepare = "${pkgs.sudo}/bin/sudo -u postgres ${cfg.package}/bin/pg_dumpall > postgresql-dump.sql";
  };
}
