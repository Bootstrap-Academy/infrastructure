{
  config,
  lib,
  pkgs,
  options,
  inputs,
  ...
}:
let
  backend = config.academy.backend;
  cfg = backend.profilePublication;
  test = config.networking.hostName == "test";
  selected = name: inputs.${name + lib.optionalString test "-develop"};
  contains =
    source: file: text:
    builtins.pathExists "${source}/${file}"
    && lib.hasInfix text (builtins.readFile "${source}/${file}");
  capabilities = {
    backend =
      contains (selected "backend") "academy_models/src/publication.rs" "academy-verified-v1"
      &&
        contains (selected "backend") "academy_api/rest/src/routes/publication.rs"
          "/auth/_internal/profile-publications/epoch";
    skills =
      contains (selected "skills-ms") "api/services/publications.py" "academy-verified-v1"
      && contains (selected "skills-ms") "api/services/publications.py" "epoch.require_enabled()"
      && contains (selected "skills-ms") "api/settings.py" "profile_publications_enabled";
    challenges =
      contains (selected "challenges-ms") "lib/src/services/publications.rs" "academy-verified-v1"
      &&
        contains (selected "challenges-ms") "challenges/src/services/leaderboard/published.rs"
          ".require_shared(enabled)"
      &&
        contains (selected "challenges-ms") "lib/src/config/challenges.rs"
          "profile_publications_enabled";
  };
  available =
    options ? services.academy.backend.settings
    && options ? academy.backend.skills.settings
    && options ? academy.backend.challenges.settings;
  shared = cfg.mode == "shared" && !config.academy.v2Recovery;
  uses =
    path: script:
    lib.hasInfix (builtins.unsafeDiscardStringContext path) (
      builtins.unsafeDiscardStringContext script
    );
  protected = ''
    proxy_cache off;
    proxy_no_cache 1;
    proxy_cache_bypass 1;
    proxy_set_header If-None-Match "";
    proxy_set_header If-Modified-Since "";
    proxy_hide_header ETag;
    proxy_hide_header Last-Modified;
    proxy_intercept_errors on;
    error_page 304 =503 @academy_publication_uncacheable;
    etag off;
    if_modified_since off;
    more_clear_headers 'ETag' 'Last-Modified';
    more_set_headers 'Cache-Control: private, no-store';
    more_set_headers 'Vary: Authorization, Cookie, Origin';
    more_set_headers "Access-Control-Allow-Origin: $allow_origin";
    more_set_headers "Access-Control-Allow-Headers: *, Authorization";
    more_set_headers "Access-Control-Allow-Methods: *";
  '';
  proxy = port: rewrite: extra: {
    priority = 150;
    proxyPass = "http://127.0.0.1:${toString port}";
    extraConfig = protected + extra + lib.optionalString (rewrite != "") "rewrite ${rewrite} break;\n";
  };
  marker = "/persistent/data/academy-profile-publication/private-policy";
  # Runtime only: a reboot or a failed guard run leaves rankings and profiles closed.
  runtime = "/run/academy-profile-publication";
  ingress = if config.academy.v2Recovery then "recovery" else cfg.mode;
  released = "${runtime}/released-${ingress}";
  # libpq keyword/value string of the backend; without dbname libpq uses the user name.
  conninfo = config.services.academy.backend.settings.database.url or "";
  conninfoValue =
    key:
    let
      match = builtins.match "(.*[[:space:]])?${key}=([^[:space:]]+).*" conninfo;
    in
    if match == null then null else builtins.elemAt match 1;
  database = if conninfoValue "dbname" != null then conninfoValue "dbname" else conninfoValue "user";
in
{
  options.academy.backend.profilePublication = {
    enable = lib.mkEnableOption "PRIV-01 ingress, coordinated settings and recovery fencing";
    mode = lib.mkOption {
      type = lib.types.enum [
        "prepare"
        "closed"
        "shared"
      ];
      default = "prepare";
      description = "Prepare retains legacy visibility before activation; closed fences transition/old readers; shared requires PRIV-01 readers and an activated database policy.";
    };
    activated = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Set once the durable policy is active on this host. Keeps the module enabled, excludes prepare and renews the persistent marker on every guard run, recovery included.";
    };
    capabilities = lib.mkOption {
      type = lib.types.attrsOf lib.types.bool;
      readOnly = true;
      default = capabilities;
      description = "Source contracts of the selected host inputs; not a replacement for independent application review.";
    };
  };

  config = lib.mkIf (cfg.enable || cfg.activated) (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion =
              backend.enable
              && available
              && builtins.elem config.networking.hostName [
                "test"
                "prod"
              ];
            message = "PRIV-01 requires the backend, Skills and Challenges on the test/prod application host.";
          }
          {
            assertion = cfg.enable;
            message = "PRIV-01 must stay enabled after activation.";
          }
          {
            assertion = !(cfg.activated && cfg.mode == "prepare");
            message = "PRIV-01 prepare would reopen legacy rankings on an activated host; use closed or shared.";
          }
          {
            assertion = backend.protectInternalEndpoints;
            message = "PRIV-01 requires protected internal ingress.";
          }
          {
            assertion =
              conninfoValue "host" == "/run/postgresql"
              && database != null
              && builtins.match "[A-Za-z0-9_]+" database != null;
            message = "PRIV-01 reads the policy of the backend database over the local PostgreSQL socket; services.academy.backend.settings.database.url must name host=/run/postgresql and a plain dbname or user.";
          }
          {
            assertion = shared -> lib.all lib.id (builtins.attrValues capabilities);
            message = "PRIV-01 shared mode requires all three selected packages to support academy-verified-v1; use closed mode for old or mixed readers.";
          }
          {
            assertion =
              (shared && lib.all lib.id (builtins.attrValues capabilities))
              -> (
                config.services.academy.backend.package.outPath == (selected "backend")
                .packages.${pkgs.stdenv.hostPlatform.system}.default.outPath
                && uses "${(selected "skills-ms").packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/api" config.systemd.services.academy-skills.script
                && uses "${(selected "challenges-ms").packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/challenges" config.systemd.services.academy-challenges.script
              );
            message = "PRIV-01 shared mode must run the capability-checked packages, without an independent package or service override.";
          }
        ];

        # Only the existence of this marker is public; contents stay root-only.
        # Neither config rollback nor recovery removes the activation marker.
        systemd.tmpfiles.rules = [
          "d /persistent/data/academy-profile-publication 0711 root root -"
          "d ${runtime} 0711 root root -"
        ];
        systemd.services.academy-profile-publication-guard = {
          description = "Check durable PRIV-01 policy before opening rankings and profiles";
          # Ordering only: the guard never starts PostgreSQL; an outage just closes the surfaces.
          after = [
            "postgresql.service"
            "postgresql-setup.service"
          ];
          before = [ "nginx.service" ];
          serviceConfig = {
            Type = "oneshot";
            TimeoutStartSec = "1min";
            # Backstop for a killed or crashed run: no release flag survives a failure.
            ExecStopPost = toString (
              pkgs.writeShellScript "academy-profile-publication-close" ''
                [ "$SERVICE_RESULT" = success ] || ${pkgs.coreutils}/bin/rm -f ${runtime}/released-*
              ''
            );
          };
          script = ''
            set -euo pipefail
            ${pkgs.python3}/bin/python3 ${../../scripts/profile-publication-guard.py} \
              --mode ${ingress}${lib.optionalString cfg.activated " --activated"} \
              --marker ${marker} --release-dir ${runtime} --database ${toString database} \
              --psql ${config.services.postgresql.package}/bin/psql \
              --runuser ${pkgs.util-linux}/bin/runuser
          '';
        };
        # Retries after a failure and re-checks the policy while Nginx keeps running.
        systemd.timers.academy-profile-publication-guard = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnActiveSec = "30s";
            OnUnitInactiveSec = "1min";
            AccuracySec = "5s";
          };
        };
        # Nginx always starts; a failed guard closes only rankings and profiles.
        systemd.services.nginx = {
          wants = [ "academy-profile-publication-guard.service" ];
          after = [ "academy-profile-publication-guard.service" ];
        };

        services.nginx.virtualHosts.${backend.domain} = {
          # Server-level checks also cover OPTIONS and run before location rewrites.
          # Only a successful guard run of this mode opens; closed and recovery never do.
          # A persistent marker must be installed BEFORE the database activation.
          extraConfig = lib.mkBefore ''
            set $academy_publication_closed 1;
            ${lib.optionalString
              (builtins.elem ingress [
                "prepare"
                "shared"
              ])
              ''
                if (-f ${released}) {
                  set $academy_publication_closed 0;
                }
              ''
            }
            ${lib.optionalString (ingress == "prepare") ''
              if (-f ${marker}) {
                set $academy_publication_closed 1;
              }
            ''}
            if ($academy_publication_unavailable) {
              return 503;
            }
            more_set_headers -s 503 'Cache-Control: private, no-store';
            more_set_headers -s 503 'Vary: Authorization, Cookie, Origin';
          '';
          locations = {
            "@academy_publication_uncacheable" = {
              return = "503";
              extraConfig = protected;
            };
            "~* /_internal(?:/|$)" = {
              priority = 50;
              return = "403";
              extraConfig = protected;
            };
            "~ ^/auth/users(?:/|$)" = proxy 8000 "" "";
            "~ ^/auth/(?:oauth/links|moderation)(?:/|$)" = proxy 8000 "" "";
            "~ ^/shop/(?:coins|hearts|premium)(?:/|$)" = proxy 8000 "" "";
            "~ ^/admin/audit-log(?:/|$)" = proxy 8000 "" "";
            "~ ^/auth/sessions?(?:/|$)" = proxy 8000 "" "";
            "~ ^/profiles(?:/|$)" = proxy 8000 "" "";
            "~ ^/skills/xp(?:/|$)" = proxy backend.microservices.skills.port "^/skills(/.*)$ $1" "";
            "~ ^/challenges/leaderboard(?:/|$)" =
              proxy backend.microservices.challenges.port "^/challenges(/.*)$ $1"
                "";
          };
        };
        services.nginx.appendHttpConfig = ''
          map $uri $academy_publication_surface {
            default 0;
            ~^/(challenges/leaderboard|profiles)(/|$) 1;
          }
          map "$academy_publication_closed:$academy_publication_surface" $academy_publication_unavailable {
            default 0;
            "1:1" 1;
          }
        '';
      }
      (lib.optionalAttrs available {
        services.academy.backend.settings.publication.enabled = lib.mkIf capabilities.backend (
          lib.mkForce shared
        );
        academy.backend.skills.settings.PROFILE_PUBLICATIONS_ENABLED = lib.mkIf capabilities.skills (
          lib.mkForce (lib.boolToString shared)
        );
        academy.backend.challenges.settings.challenges.profile_publications_enabled =
          lib.mkIf capabilities.challenges (lib.mkForce shared);
      })
    ]
  );
}
