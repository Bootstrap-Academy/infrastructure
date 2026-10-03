{ self, pkgs, ... }:
let
  prepared =
    (self.nixosConfigurations.test.extendModules {
      modules = [ { academy.backend.profilePublication.enable = true; } ];
    }).config;
  vhost = prepared.services.nginx.virtualHosts.${prepared.academy.backend.domain};
in
pkgs.testers.runNixOSTest {
  name = "profile-publication-ingress-recovery";
  nodes.machine = { pkgs, ... }: {
    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_18;
      ensureDatabases = [ "academy" ];
    };
    services.nginx = {
      enable = true;
      package = prepared.services.nginx.package;
      additionalModules = prepared.services.nginx.additionalModules;
      recommendedProxySettings = true;
      appendHttpConfig = prepared.services.nginx.appendHttpConfig;
      virtualHosts.fixture =
        builtins.removeAttrs vhost [
          "allow"
          "deny"
        ]
        // {
          forceSSL = false;
          enableACME = false;
          quic = false;
          listen = [
            {
              addr = "0.0.0.0";
              port = 8080;
            }
          ];
        };
    };
    environment.systemPackages = [
      pkgs.python3
      pkgs.curl
      pkgs.util-linux
    ];
    environment.etc."publication-guard.py".source = ../scripts/profile-publication-guard.py;
    systemd.tmpfiles.rules = [ "d /persistent/data/academy-profile-publication 0711 root root -" ];
    systemd.services.publication-fixture = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig.ExecStart = "${pkgs.python3}/bin/python3 ${./profile-publication-fixture.py}";
    };
  };
  testScript = ''
    start_all()
    machine.wait_for_unit("postgresql.service")
    machine.wait_for_unit("publication-fixture.service")
    machine.wait_for_unit("nginx.service")
    machine.wait_for_open_port(8080)
    guard = "python3 /etc/publication-guard.py --marker /persistent/data/academy-profile-publication/private-policy --psql ${pkgs.postgresql_18}/bin/psql --runuser ${pkgs.util-linux}/bin/runuser --mode "
    machine.succeed(guard + "prepare")
    machine.succeed("test ! -e /persistent/data/academy-profile-publication/private-policy")
    machine.succeed("curl -fsS http://127.0.0.1:8080/challenges/leaderboard | grep fixture")
    # Shared config never authorizes an absent/inactive persistent policy.
    machine.fail(guard + "shared")
    machine.succeed("test -f /persistent/data/academy-profile-publication/private-policy")
    machine.succeed("python3 ${./profile-publication-fixture.py} check closed")
    # Fixture reset is confined to this disposable VM; operators never remove it.
    machine.succeed("rm /persistent/data/academy-profile-publication/private-policy")
    machine.succeed("python3 ${./profile-publication-fixture.py} check prepare")
    machine.succeed("sudo -u postgres psql -d academy -c \"CREATE TABLE profile_publication_state(singleton boolean PRIMARY KEY, policy_active boolean NOT NULL, scope_version text); INSERT INTO profile_publication_state VALUES(true,false,NULL);\"")
    machine.succeed(guard + "prepare")
    machine.fail(guard + "shared")
    machine.succeed("sudo -u postgres psql -d academy -c \"UPDATE profile_publication_state SET policy_active=true,scope_version='academy-verified-v1';\"")
    machine.succeed(guard + "shared")
    # Returning to a preparation generation cannot remove the persistent fence.
    machine.succeed(guard + "prepare")
    machine.succeed("python3 ${./profile-publication-fixture.py} check closed")
    machine.succeed("systemctl restart nginx")
    machine.succeed("python3 ${./profile-publication-fixture.py} check closed")
    machine.succeed("sudo -u postgres psql -d academy -c \"UPDATE profile_publication_state SET scope_version='unknown-scope';\"")
    machine.fail(guard + "shared")
    machine.succeed("python3 ${./profile-publication-fixture.py} check closed")
    machine.succeed("systemctl stop postgresql")
    machine.fail(guard + "prepare")
    machine.succeed("python3 ${./profile-publication-fixture.py} check closed")
  '';
}
