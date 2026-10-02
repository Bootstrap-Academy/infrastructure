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

  # Upstream REL_18_STABLE fix: a second startup crash must let the
  # postmaster exit so systemd can restart it, rather than stay in recovery.
  newPostgres =
    if lib.versionAtLeast pkgs.postgresql_18.version "18.7" then
      pkgs.postgresql_18
    else
      pkgs.postgresql_18.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./patches/postgresql-18-startup-crash-exit.patch ];
      });
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
      package = newPostgres;
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
    backup.prepare = ''
      (
        set -euo pipefail
        dump=$(mktemp postgresql-dump.sql.gz.XXXXXX)
        trap 'rm -f "$dump"' EXIT
        ${pkgs.sudo}/bin/sudo -u postgres ${cfg.finalPackage}/bin/pg_dumpall \
          | ${pkgs.gzip}/bin/gzip -n -1 --rsyncable > "$dump"
        mv "$dump" postgresql-dump.sql.gz
      )
    '';
  };
}
