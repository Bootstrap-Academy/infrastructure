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
    capabilities = lib.mkOption {
      type = lib.types.attrsOf lib.types.bool;
      readOnly = true;
      default = capabilities;
      description = "Source contracts of the selected host inputs; not a replacement for independent application review.";
    };
  };

  config = lib.mkIf cfg.enable (
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
            assertion = backend.protectInternalEndpoints;
            message = "PRIV-01 requires protected internal ingress.";
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
        systemd.tmpfiles.rules = [ "d /persistent/data/academy-profile-publication 0711 root root -" ];
        systemd.services.academy-profile-publication-guard = {
          description = "Check durable PRIV-01 policy before opening API ingress";
          requires = [ "postgresql.service" ];
          after = [ "postgresql.service" ];
          before = [ "nginx.service" ];
          serviceConfig.Type = "oneshot";
          script = ''
            set -euo pipefail
            ${pkgs.python3}/bin/python3 ${../../scripts/profile-publication-guard.py} \
              --mode ${if config.academy.v2Recovery then "closed" else cfg.mode} \
              --marker ${marker} --psql ${config.services.postgresql.package}/bin/psql \
              --runuser ${pkgs.util-linux}/bin/runuser
          '';
        };
        systemd.services.nginx = {
          requires = [ "academy-profile-publication-guard.service" ];
          after = [ "academy-profile-publication-guard.service" ];
        };

        services.nginx.virtualHosts.${backend.domain} = {
          # Server-level checks also cover OPTIONS and run before location rewrites.
          # A runtime marker must be installed BEFORE the database activation.
          extraConfig = lib.mkBefore ''
            set $academy_publication_closed ${
              if cfg.mode == "closed" || config.academy.v2Recovery then "1" else "0"
            };
            ${lib.optionalString (!shared) ''
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
