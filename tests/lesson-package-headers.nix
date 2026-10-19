{ self }:

let
  # Test the deployed Nginx on its native architecture, as private-lesson-headers.nix does.
  pkgs = self.nixosConfigurations.test.pkgs;
  fixtures =
    map
      (
        host:
        let
          # Lesson packages on the backend's own host: Test serves them so, Prod gets the same when switched on.
          cfg =
            (self.nixosConfigurations.${host}.extendModules {
              modules = [
                ({ config, lib, ... }: {
                  academy.backend.lessonContent = {
                    enable = true;
                    host = lib.mkForce config.academy.backend.domain;
                  };
                })
              ];
            }).config;
          vhost = cfg.services.nginx.virtualHosts.${cfg.academy.backend.domain};
          fixture = pkgs.writeText "lesson-package-headers-${host}.json" (
            builtins.toJSON {
              inherit host;
              domain = cfg.academy.backend.domain;
              frontend = cfg.academy.backend.frontend;
              origin = cfg.academy.backend.skills.settings.ENGINE_CONTENT_ORIGIN;
              http =
                builtins.replaceStrings [ "/var/log/nginx" ] [ "@RUNTIME@" ]
                  cfg.services.nginx.appendHttpConfig;
              server = vhost.extraConfig;
              packages = vhost.locations."^~ /packages/".extraConfig;
            }
          );
          nginx = cfg.services.nginx.package;
        in
        ''
          python ${../scripts/test-lesson-package-headers.py} \
            --nginx ${nginx}/bin/nginx --mime-types ${nginx}/conf/mime.types \
            --fixture ${fixture} --output "$out/${host}.json"
        ''
      )
      [
        "test"
        "prod"
      ];
in
pkgs.runCommand "lesson-package-header-tests"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.openssl
    ];
  }
  ''
    mkdir "$out"
    ${builtins.concatStringsSep "\n" fixtures}
  ''
