{
  config,
  lib,
  pkgs,
  name,
  ...
}:

let
  cfg = config.academy.backend.lessonModules;
in
{
  options.academy.backend.lessonModules = {
    enable = lib.mkEnableOption "immutable reviewed browser module files on the existing API host";
    root = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/academy-static";
      description = "Static root; the internal publisher installs packages in its lesson-modules subdirectory.";
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
              assertion =
                config.academy.backend.enable
                && builtins.elem config.networking.hostName [
                  "test"
                  "prod"
                ];
              message = "Lesson modules use the existing test/prod Academy API host.";
            }
            {
              assertion = builtins.match "/[A-Za-z0-9/_-]+" cfg.root != null;
              message = "The static root must be an absolute path without shell or nginx metacharacters.";
            }
          ];

          systemd.tmpfiles.rules = [
            "d ${cfg.root} 0755 root root -"
            "d ${cfg.root}/lesson-modules 0755 root root -"
          ];
          environment.persistence."/persistent/data".directories = [ cfg.root ];
          environment.systemPackages = [
            (pkgs.writeShellScriptBin "academy-publish-learning-module" ''
              exec ${pkgs.nodejs}/bin/node ${../../scripts/publish-learning-module.mjs} "$@"
            '')
          ];
          academy.backend.skills.settings = {
            LESSON_MODULE_ORIGINS = builtins.toJSON [ "https://${config.academy.backend.domain}" ];
            LESSON_MODULE_LOCAL_DEVELOPMENT = "false";
          };

          services.nginx.virtualHosts.${config.academy.backend.domain}.locations."^~ /lesson-modules/" = {
            root = cfg.root;
            tryFiles = "$uri =404";
            extraConfig = ''
              # Only complete hash-addressed assets; never an API/SPA fallback or index.
              if ($uri !~ "^/lesson-modules/[0-9a-f]{64}/.+$") { return 404; }
              if ($uri ~ "/\\.") { return 404; }
              if ($uri ~ "/$") { return 404; }
              autoindex off;
              disable_symlinks on;
              limit_except GET { deny all; }
              default_type application/octet-stream;
              types {
                application/javascript js mjs;
                text/css css;
                application/json json map;
                application/wasm wasm;
                image/svg+xml svg;
                image/png png;
                image/jpeg jpg jpeg;
                image/webp webp;
                image/avif avif;
                image/gif gif;
                font/woff woff;
                font/woff2 woff2;
                font/ttf ttf;
                font/otf otf;
                video/mp4 mp4;
                video/webm webm;
                audio/mpeg mp3;
                audio/ogg ogg;
              }
              more_set_headers "Access-Control-Allow-Origin: *";
              more_set_headers "Access-Control-Allow-Methods: GET, HEAD";
              more_clear_headers "Access-Control-Allow-Credentials";
              # Preserve inherited HSTS/frame/referrer headers. A nested add_header
              # would replace the entire parent add_header set.
              more_set_headers -s "200 206 304" "Cache-Control: public, max-age=31536000, immutable";
              more_set_headers "X-Content-Type-Options: nosniff";
            '';
          };
        }
      );
}
