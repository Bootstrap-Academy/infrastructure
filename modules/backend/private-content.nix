{
  config,
  lib,
  name,
  ...
}:
let
  cfg = config.academy.backend.privateContent;
  domain = config.academy.backend.domain;
  skillsPort = toString config.academy.backend.microservices.skills.port;
  # Own the policy at the final location; inherited add_header runs after
  # headers-more and can also run twice when a Range filter produces an error.
  # The pinned Nginx supports add_header_inherit (since 1.29.3). Keep the vhost's
  # headers-more CORS policy and explicitly preserve its HSTS/frame protections.
  privateHeaders = ''
    add_header_inherit off;
    # X-Accel retains upstream Cache-Control even with proxy_hide_header.
    # Replace values idempotently, including on reprocessed error responses.
    more_set_headers "Cache-Control: private, no-store";
    more_set_headers "Referrer-Policy: no-referrer";
    more_set_headers "X-Content-Type-Options: nosniff";
    more_set_headers "X-Frame-Options: DENY";
    more_set_headers "Strict-Transport-Security: $hsts_header";
  '';
in
{
  options.academy.backend.privateContent = {
    enable = lib.mkEnableOption "private course definitions and authorized lesson assets";
    root = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/academy-content";
      description = "Private runtime content, published separately from public Git and Nix sources.";
    };
  };

  config =
    lib.optionalAttrs
      (builtins.elem name [
        "test"
        "prod"
      ])
      (
        lib.mkIf cfg.enable {
          assertions = [
            {
              assertion = config.academy.backend.enable && config.academy.backend.lessonModules.enable;
              message = "Private content requires the Academy backend and reviewed module publisher.";
            }
            {
              assertion = builtins.match "/[A-Za-z0-9/_-]+" cfg.root != null;
              message = "The private content root must be an absolute path without shell or nginx metacharacters.";
            }
            {
              assertion =
                !(lib.hasPrefix "${config.academy.backend.lessonModules.root}/" "${cfg.root}/")
                && !(lib.hasPrefix "/nix/store/" "${cfg.root}/");
              message = "Private content must remain outside the public module root and Nix store.";
            }
          ];

          users.groups.academy-content = { };
          users.users.nginx.extraGroups = [ "academy-content" ];
          systemd.services.academy-skills.serviceConfig.SupplementaryGroups = [ "academy-content" ];
          systemd.services.academy-skills-sweep-deleted-users.serviceConfig.SupplementaryGroups = [
            "academy-content"
          ];
          systemd.tmpfiles.rules = [
            "d ${cfg.root} 0750 root academy-content -"
            "d ${cfg.root}/catalog 0750 root academy-content -"
            "d ${cfg.root}/catalog/courses 0750 root academy-content -"
            "d ${cfg.root}/modules 0750 root academy-content -"
          ];
          environment.persistence."/persistent/data".directories = [
            {
              directory = cfg.root;
              user = "root";
              group = "academy-content";
              mode = "0750";
            }
          ];
          academy.backend.skills.settings = {
            LEARNING_ROOMS_CONTENT = "${cfg.root}/catalog/learning_rooms.json";
            PRIVATE_COURSES_DIRECTORY = "${cfg.root}/catalog/courses";
            PRIVATE_LESSON_MODULES_ROOT = "${cfg.root}/modules";
            PRIVATE_LESSON_MODULE_GRANT_TTL = "3600";
          };

          services.nginx.virtualHosts.${domain}.locations = {
            # The canonical registry URL is deliberately not a public file route.
            "^~ /private-lesson-modules/".return = "404";

            "^~ /skills/lesson-assets/" = {
              proxyPass = "http://127.0.0.1:${skillsPort}/lesson-assets/";
              extraConfig = ''
                access_log off;
                error_log /dev/null crit;
                limit_except GET { deny all; }
                # Normalize older Skills versions during a staggered rollout.
                proxy_hide_header Cache-Control;
                proxy_hide_header Referrer-Policy;
                proxy_hide_header X-Content-Type-Options;
                proxy_hide_header X-Frame-Options;
                proxy_hide_header Strict-Transport-Security;
                ${privateHeaders}
              '';
            };

            "^~ /_private-lesson-modules/" = {
              alias = "${cfg.root}/modules/";
              extraConfig = ''
                internal;
                autoindex off;
                disable_symlinks on;
                access_log off;
                error_log /dev/null crit;
                limit_except GET { deny all; }
                # Skills checked the grant and the exact manifest entry first.
                ${privateHeaders}
              '';
            };
          };
        }
      );
}
