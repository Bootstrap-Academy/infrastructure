{
  pkgs,
  lib,
  config,
  ...
}: let
  databases = [
    "academy-auth"
  ];
in {
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    enableTCPIP = true;
    ensureDatabases = databases;
    ensureUsers =
      map (db: {
        name = db;
        ensureDBOwnership = true;
      })
      databases;
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
        password := trim(both from replace(pg_read_file('${config.sops.secrets."postgresql/passwords/academy-auth".path}'), E'\n', '''));
        EXECUTE format('ALTER ROLE "academy-auth" WITH PASSWORD '''%s''';', password);
      END $$;
    EOF
  '';

  sops.secrets."postgresql/passwords/academy-auth" = {
    owner = "postgres";
    group = "postgres";
  };
}
