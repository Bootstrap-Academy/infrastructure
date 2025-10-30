{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.services.nginx.virtualHosts = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (virtualHost: {
        options = {
          allow = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
          };
          deny = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
          };
        };

        config = {
          quic = lib.mkDefault true;
          deny = lib.mkIf (virtualHost.config.allow != [ ]) (lib.mkDefault [ "all" ]);
          extraConfig =
            lib.concatMapStrings (x: "allow ${x};\n") virtualHost.config.allow
            + lib.concatMapStrings (x: "deny ${x};\n") virtualHost.config.deny;
        };
      })
    );
  };

  config = lib.mkIf config.services.nginx.enable {
    services.nginx = {
      package = pkgs.nginxQuic;
      enableReload = true;
      statusPage = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedZstdSettings = true;
      recommendedGzipSettings = true;
      recommendedBrotliSettings = true;

      appendHttpConfig = ''
        # https://nixos.wiki/wiki/Nginx#Hardened_setup_with_TLS_and_HSTS_preloading
        # Add HSTS header with preloading to HTTPS requests.
        # Adding this header to HTTP requests is discouraged
        map $scheme $hsts_header {
            https   "max-age=31536000; includeSubdomains; preload";
        }
        add_header Strict-Transport-Security $hsts_header;

        # Enable CSP for your services.
        #add_header Content-Security-Policy "script-src 'self'; object-src 'none'; base-uri 'none';" always;

        # Minimize information leaked to other domains
        add_header 'Referrer-Policy' 'origin-when-cross-origin';

        # Disable embedding as a frame
        add_header X-Frame-Options DENY;

        # Prevent injection of code in other mime types (XSS Attacks)
        add_header X-Content-Type-Options nosniff;

        # This might create errors
        # proxy_cookie_path / "/; secure; HttpOnly; SameSite=strict";

        log_format prometheus '${config.monitoring.nginxLogFormat}';
        access_log /var/log/nginx/prometheus.log prometheus;
        access_log /var/log/nginx/access.log combined;

        more_set_headers 'Alt-Svc: h3=":443"; ma=86400';
      '';
    };

    security.acme = {
      acceptTerms = true;
      defaults.email = "admin@bootstrap.academy";
    };
  };
}
