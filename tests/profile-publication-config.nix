{
  self,
  lib,
  writeText,
}:
let
  guard = "academy-profile-publication-guard.service";
  describe =
    publication: extra:
    let
      cfg =
        (self.nixosConfigurations.test.extendModules {
          # Force the scenario values: a host may already set the module, as Test does.
          modules = [
            { academy.backend.profilePublication = lib.mapAttrs (_: lib.mkForce) publication; }
          ]
          ++ extra;
        }).config;
      nginx = cfg.systemd.services.nginx;
    in
    {
      capable = lib.all lib.id (builtins.attrValues cfg.academy.backend.profilePublication.capabilities);
      failures = map (item: item.message) (builtins.filter (item: !item.assertion) cfg.assertions);
      flags = [
        (cfg.services.academy.backend.settings.publication.enabled or null)
        (cfg.academy.backend.skills.settings.PROFILE_PUBLICATIONS_ENABLED or null)
        (cfg.academy.backend.challenges.settings.challenges.profile_publications_enabled or null)
      ];
      ingress = cfg.services.nginx.virtualHosts.${cfg.academy.backend.domain}.extraConfig;
      guard = cfg.systemd.services.academy-profile-publication-guard.script;
      nginxWantsGuard = builtins.elem guard nginx.wants && builtins.elem guard nginx.after;
      nginxRequiresGuard = builtins.elem guard nginx.requires || builtins.elem guard nginx.requisite;
      guardRequiresPostgres =
        cfg.systemd.services.academy-profile-publication-guard.requires != [ ]
        || cfg.systemd.services.academy-profile-publication-guard.wants != [ ];
      timer = cfg.systemd.timers.academy-profile-publication-guard.wantedBy;
    };
  modes = {
    prepare = describe { enable = true; } [ ];
    closed = describe {
      enable = true;
      mode = "closed";
    } [ ];
    shared = describe {
      enable = true;
      mode = "shared";
    } [ ];
    recovery = describe {
      enable = true;
      mode = "shared";
    } [ { academy.v2Recovery = true; } ];
    activatedClosed = describe {
      enable = true;
      mode = "closed";
      activated = true;
    } [ ];
    activatedPrepare = describe {
      enable = true;
      activated = true;
    } [ ];
    activatedDisabled = describe {
      enable = false;
      activated = true;
    } [ ];
    sharedForeignPackage = describe {
      enable = true;
      mode = "shared";
    } [ ({ pkgs, ... }: { services.academy.backend.package = lib.mkForce pkgs.hello; }) ];
    prepareUnprotected = describe { enable = true; } [
      { academy.backend.protectInternalEndpoints = lib.mkForce false; }
    ];
    prepareRemoteDatabase = describe { enable = true; } [
      { services.academy.backend.settings.database.url = lib.mkForce "host=db.internal user=academy"; }
    ];
  };
  has = text: lib.hasInfix text;
  off = lib.all (flag: flag == null || flag == false || flag == "false");
  fails = message: mode: lib.any (has message) mode.failures;
  wired =
    mode:
    mode.nginxWantsGuard
    && !mode.nginxRequiresGuard
    && !mode.guardRequiresPostgres
    && mode.timer == [ "timers.target" ];
  expectations = with modes; {
    "prepare is valid, closed by default and opened only by its own release flag" =
      prepare.failures == [ ]
      && off prepare.flags
      && has "set $academy_publication_closed 1;" prepare.ingress
      && has "/run/academy-profile-publication/released-prepare" prepare.ingress
      && has "private-policy" prepare.ingress
      && has "--mode prepare " prepare.guard
      && !(has "--activated" prepare.guard)
      && has "--database academy " prepare.guard
      && wired prepare;
    "closed never opens and keeps the services switched off" =
      closed.failures == [ ]
      && off closed.flags
      && !(has "released-" closed.ingress)
      && has "--mode closed " closed.guard
      && wired closed;
    "shared needs all capabilities and opens only through released-shared" =
      (
        if shared.capable then
          shared.failures == [ ]
          &&
            shared.flags == [
              true
              "true"
              true
            ]
        else
          fails "requires all three selected packages" shared
      )
      && has "/run/academy-profile-publication/released-shared" shared.ingress
      && !(has "private-policy" shared.ingress)
      && has "--mode shared " shared.guard
      && wired shared;
    "recovery closes statically and the guard never opens" =
      recovery.failures == [ ]
      && off recovery.flags
      && !(has "released-" recovery.ingress)
      && has "--mode recovery " recovery.guard
      && wired recovery;
    "an activated host renews the marker in every guard run" =
      activatedClosed.failures == [ ] && has "--mode closed --activated " activatedClosed.guard;
    "an activated host rejects prepare" = fails "prepare would reopen legacy rankings" activatedPrepare;
    "an activated host keeps the module enabled" = fails "must stay enabled" activatedDisabled;
    "a package outside the checked inputs never opens shared" = sharedForeignPackage.failures != [ ];
    "unprotected internal ingress is rejected" = fails "protected internal ingress" prepareUnprotected;
    "a database outside the local socket is rejected" =
      fails "local PostgreSQL socket" prepareRemoteDatabase;
  };
  broken = builtins.attrNames (lib.filterAttrs (_: ok: !ok) expectations);
in
assert lib.assertMsg (
  broken == [ ]
) "profile publication configuration: ${lib.concatStringsSep "; " broken}";
writeText "profile-publication-config.json" (
  builtins.toJSON (lib.mapAttrs (_: mode: { inherit (mode) capable failures flags; }) modes)
)
