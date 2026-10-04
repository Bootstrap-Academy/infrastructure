{
  self,
  lib,
  pkgs,
  ...
}:
let
  host =
    mode: extra:
    (self.nixosConfigurations.test.extendModules {
      modules = [
        {
          academy.backend.profilePublication = {
            enable = lib.mkForce true;
            mode = lib.mkForce mode;
          };
        }
      ]
      ++ extra;
    }).config;
  prepared = host "prepare" [ ];
  vhost = c: c.services.nginx.virtualHosts.${c.academy.backend.domain};
  guard = c: c.systemd.services.academy-profile-publication-guard;
  ours = lib.hasInfix "academy-profile-publication";
  # Each generation differs only in ingress checks and guard mode, switched like a deploy.
  generation = c: {
    services.nginx.virtualHosts.fixture.extraConfig = lib.mkForce (vhost c).extraConfig;
    systemd.services.academy-profile-publication-guard = {
      serviceConfig = lib.mkForce (guard c).serviceConfig;
    };
  };
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
      inherit (prepared.services.nginx)
        package
        additionalModules
        appendHttpConfig
        enableReload
        ;
      recommendedProxySettings = true;
      virtualHosts.fixture =
        builtins.removeAttrs (vhost prepared) [
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
      # Unrelated virtual host: answers whatever the guard reports.
      virtualHosts.other = {
        listen = [
          {
            addr = "0.0.0.0";
            port = 8081;
          }
        ];
        locations."/".return = "200 other";
      };
    };
    environment.systemPackages = [
      pkgs.python3
      pkgs.curl
    ];
    # The module's own guard unit, timer, runtime directories and Nginx dependency form.
    systemd.tmpfiles.rules = builtins.filter ours prepared.systemd.tmpfiles.rules;
    systemd.services.academy-profile-publication-guard = {
      inherit (guard prepared)
        description
        after
        before
        wants
        requires
        serviceConfig
        ;
    };
    systemd.timers.academy-profile-publication-guard = {
      inherit (prepared.systemd.timers.academy-profile-publication-guard) wantedBy timerConfig;
    };
    systemd.services.nginx = lib.mapAttrs (_: builtins.filter ours) {
      inherit (prepared.systemd.services.nginx) wants requires after;
    };
    specialisation = lib.mapAttrs (_: c: { configuration = generation c; }) {
      closed = host "closed" [ ];
      shared = host "shared" [ ];
      recovery = host "shared" [ { academy.v2Recovery = true; } ];
    };
    systemd.services.publication-fixture = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig.ExecStart = "${pkgs.python3}/bin/python3 ${./profile-publication-fixture.py}";
    };
  };
  testScript = ''
    marker = "/persistent/data/academy-profile-publication/private-policy"
    runtime = "/run/academy-profile-publication"
    guard = "academy-profile-publication-guard"
    psql = "sudo -u postgres psql -d academy -c "

    def check(state):
        machine.succeed("python3 ${./profile-publication-fixture.py} check " + state)

    def released():
        return machine.succeed(f"ls {runtime}").split()

    def switch(name):
        system = "/run/booted-system" + ("" if name == "prepare" else "/specialisation/" + name)
        machine.succeed(system + "/bin/switch-to-configuration test")

    def nginx_restart_during_outage():
        # A failed guard never takes Nginx or other virtual hosts down.
        machine.succeed("systemctl stop postgresql")
        machine.succeed("systemctl restart nginx")
        machine.succeed("systemctl is-active nginx")
        machine.succeed(f"systemctl show -p Result --value {guard} | grep -qx exit-code")
        machine.succeed("curl -fsS http://127.0.0.1:8081/ | grep -q other")
        assert released() == [], released()
        check("closed")
        machine.succeed("systemctl start postgresql")

    start_all()
    machine.wait_for_unit("postgresql.service")
    machine.wait_for_unit("publication-fixture.service")
    machine.wait_for_unit("nginx.service")
    machine.wait_for_open_port(8080)
    machine.wait_for_open_port(8081)

    # The boot run confirmed a never-activated policy before Nginx started.
    assert released() == ["released-prepare"], released()
    machine.succeed(f"test ! -e {marker}")
    check("open")

    # Before activation an outage closes legacy rankings only until the timer rerun.
    nginx_restart_during_outage()
    machine.succeed(f"test ! -e {marker}")
    machine.wait_until_succeeds(f"test -e {runtime}/released-prepare", timeout=150)
    check("open")

    # A recovery before activation neither opens nor leaves a permanent fence.
    switch("recovery")
    check("closed")
    machine.succeed(f"systemctl start {guard}")
    assert released() == [], released()
    machine.succeed(f"test ! -e {marker}")
    switch("prepare")
    check("closed")
    machine.succeed(f"systemctl start {guard}")
    check("open")

    # Activation order: closed, guard run, marker, policy, then shared.
    switch("closed")
    check("closed")
    machine.succeed(f"systemctl start {guard}")
    machine.succeed(f"test -f {marker}")
    assert released() == [], released()
    machine.succeed(psql + "\"CREATE TABLE profile_publication_state(singleton boolean PRIMARY KEY, policy_active boolean NOT NULL, scope_version text); INSERT INTO profile_publication_state VALUES(true,false,NULL);\"")
    switch("shared")
    machine.fail(f"systemctl start {guard}")
    assert released() == [], released()
    check("closed")
    machine.succeed(psql + "\"UPDATE profile_publication_state SET policy_active=true,scope_version='academy-verified-v1';\"")
    machine.succeed(f"systemctl start {guard}")
    assert released() == ["released-shared"], released()
    check("open")

    # Shared: the surfaces reopen on their own once the database is back.
    nginx_restart_during_outage()
    machine.wait_until_succeeds(f"test -e {runtime}/released-shared", timeout=150)
    check("open")
    machine.succeed(psql + "\"UPDATE profile_publication_state SET scope_version='unknown-scope';\"")
    machine.fail(f"systemctl start {guard}")
    check("closed")
    machine.succeed(psql + "\"UPDATE profile_publication_state SET scope_version='academy-verified-v1';\"")
    machine.succeed(f"systemctl start {guard}")
    check("open")
    # A killed run leaves no release flag behind, even before the guard could clean up.
    machine.succeed("systemd-run --unit=policy-lock --uid=postgres ${pkgs.postgresql_18}/bin/psql -d academy -c 'BEGIN; LOCK TABLE profile_publication_state IN ACCESS EXCLUSIVE MODE; SELECT pg_sleep(300);'")
    holder = "FROM pg_locks WHERE mode='AccessExclusiveLock' AND relation='profile_publication_state'::regclass"
    machine.wait_until_succeeds(f"{psql}\"SELECT count(*) {holder}\" -qAt | grep -qx 1")
    machine.succeed(f"systemctl start --no-block {guard}")
    machine.wait_until_succeeds(f"systemctl show -p ActiveState --value {guard} | grep -qx activating")
    machine.sleep(2)
    assert released() == ["released-shared"], released()
    machine.succeed(f"systemctl kill --kill-whom=main --signal=SIGKILL {guard}")
    machine.wait_until_succeeds(f"systemctl show -p ActiveState --value {guard} | grep -qx failed")
    machine.succeed(f"systemctl show -p Result --value {guard} | grep -qx signal")
    assert released() == [], released()
    check("closed")
    machine.succeed(f"{psql}\"SELECT pg_terminate_backend(pid) {holder}\"")
    machine.succeed(f"systemctl start {guard}")
    check("open")

    # Recovery after activation stays closed and keeps the marker.
    switch("recovery")
    check("closed")
    machine.succeed(f"systemctl start {guard}")
    assert released() == [], released()
    machine.succeed(f"test -f {marker}")

    # Returning to a preparation generation cannot reopen legacy rankings.
    switch("prepare")
    machine.succeed(f"systemctl start {guard}")
    assert released() == [], released()
    check("closed")
    machine.succeed("systemctl restart nginx")
    check("closed")
    # Fixture only: even a stray prepare flag cannot open while the marker exists.
    machine.succeed(f"touch {runtime}/released-prepare")
    check("closed")
  '';
}
