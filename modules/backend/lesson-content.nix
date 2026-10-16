{
  config,
  lib,
  pkgs,
  name,
  ...
}:

let
  cfg = config.academy.backend.lessonContent;
  isIPv4 = builtins.match "([0-9]{1,3}\\.){3}[0-9]{1,3}" cfg.host != null;
  origin = "https://${cfg.host}";
  # The policy the frontend requires of a package entry (lesson-protocol/browser.ts, validateLessonCsp).
  csp = lib.concatStringsSep "; " [
    "default-src 'none'"
    "script-src 'self'"
    "style-src 'self'"
    "img-src 'self'"
    "connect-src 'none'"
    "object-src 'none'"
    "frame-src 'none'"
    "base-uri 'none'"
    "form-action 'none'"
    "frame-ancestors ${config.academy.backend.frontend}"
  ];
in
{
  options.academy.backend.lessonContent = {
    enable = lib.mkEnableOption "the session-free origin for API 2 lesson packages of the lesson engine";
    host = lib.mkOption {
      type = lib.types.str;
      example = "49.13.123.1";
      description = ''
        Host of the content origin, outside bootstrap.academy so that it carries no platform session. An IPv4
        address gets a Let's Encrypt certificate with the shortlived profile and becomes the default server on
        port 443, because browsers send no SNI for an address.
      '';
    };
    root = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/academy-lesson-content";
      description = "Persistent root; the publisher installs packages in its packages subdirectory.";
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
              message = "Lesson packages need the Academy backend and its module publisher.";
            }
            {
              assertion = builtins.match "/[A-Za-z0-9/_-]+" cfg.root != null;
              message = "The lesson content root must be an absolute path without shell or nginx metacharacters.";
            }
            {
              assertion =
                builtins.match "[a-z0-9.-]+" cfg.host != null
                && cfg.host != "bootstrap.academy"
                && !(lib.hasSuffix ".bootstrap.academy" cfg.host);
              message = "The lesson content host must lie outside bootstrap.academy (the frontend refuses it).";
            }
          ];

          systemd.tmpfiles.rules = [
            "d ${cfg.root} 0755 root root -"
            "d ${cfg.root}/packages 0755 root root -"
          ];
          environment.persistence."/persistent/data".directories = [ cfg.root ];
          environment.systemPackages = [
            (pkgs.writeShellScriptBin "academy-publish-lesson-package" ''
              exec ${pkgs.nodejs}/bin/node ${../../scripts/publish-lesson-package.mjs} "$@"
            '')
          ];

          academy.backend.skills.settings.ENGINE_CONTENT_ORIGIN = origin;

          security.acme.certs.${cfg.host} = {
            # An own ACME account (the account is server, key type and email): the module makes the first
            # certificate of an account the one all others require, so a failing order here must not hold back
            # the renewals of the API certificate.
            keyType = "ec384";
          }
          // lib.optionalAttrs isIPv4 {
            # Let's Encrypt issues certificates for IP addresses only with this profile (about 160 hours);
            # the module renews them dynamically once half of the lifetime is left.
            profile = "shortlived";
            # lego puts the first identifier into the common name; Let's Encrypt refuses an IP address there
            # ("badCSR: CSR contains IP address in Common Name", seen on Test on 16.10.2026). The SAN keeps it.
            extraLegoFlags = [ "--disable-cn" ];
          };

          # Expiry and reachability of the origin (AcademyServiceDown, and the short-lived certificate rule).
          monitoring.alerting.probes = lib.mkIf config.monitoring.alerting.enable {
            lesson-content = {
              url = "${cfg.host}:443";
              module = "tls";
              shortLivedCertificate = isIPv4;
            };
          };

          services.nginx.virtualHosts.${cfg.host} = {
            enableACME = true;
            forceSSL = true;
            # No HTTP/3: browsers would find the address through Alt-Svc, and no SNI picks the right QUIC server.
            quic = false;
            http3 = false;
            listen = [
              {
                addr = "0.0.0.0";
                port = 80;
              }
              {
                addr = "0.0.0.0";
                port = 443;
                ssl = true;
                extraParameters = lib.optional isIPv4 "default_server";
              }
            ];
            # The frontend embeds the entry in a frame, so none of the global headers (X-Frame-Options) apply here.
            extraConfig = ''
              add_header_inherit off;
              more_clear_headers "Alt-Svc";
            '';
            locations."/".return = "404";
            # Quoted: unquoted braces of the regex would end the location block for nginx.
            locations."~ \"^/packages/[0-9a-f]{64}/\"" = {
              root = cfg.root;
              extraConfig = ''
                # Hash-addressed public bytes only: no query, no hidden names, no listing, no symlinks, no redirect.
                limit_except GET { deny all; }
                if ($args != "") { return 404; }
                if ($uri ~ "/\.") { return 404; }
                autoindex off;
                disable_symlinks on;
                index index.html;
                try_files $uri $uri/index.html =404;
                default_type application/octet-stream;
                types {
                  text/html html;
                  text/javascript js mjs;
                  text/css css;
                  application/json json;
                  image/svg+xml svg;
                  image/png png;
                  image/webp webp;
                  image/avif avif;
                  audio/ogg ogg;
                  audio/mpeg mp3;
                  audio/mp4 m4a;
                }
                more_clear_headers "Alt-Svc";
                more_set_headers "Content-Security-Policy: ${csp}";
                more_set_headers "Access-Control-Allow-Origin: *";
                more_set_headers "Access-Control-Expose-Headers: Content-Security-Policy";
                more_set_headers "X-Content-Type-Options: nosniff";
                more_set_headers "Referrer-Policy: no-referrer";
                more_set_headers -s "200 304" "Cache-Control: public, max-age=31536000, immutable";
              '';
            };
          };
        }
      );
}
