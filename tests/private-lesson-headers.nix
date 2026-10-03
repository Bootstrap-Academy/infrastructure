{ self }:

let
  # Test the deployed Nginx on its native architecture, even when the check
  # farm is requested through the flake's aarch64-linux package set.
  pkgs = self.nixosConfigurations.test.pkgs;
  fixtures =
    map
      (
        host:
        let
          cfg = self.nixosConfigurations.${host}.config;
          vhost = cfg.services.nginx.virtualHosts.${cfg.academy.backend.domain};
          locations = vhost.locations;
          fixture = pkgs.writeText "private-lesson-headers-${host}.json" (
            builtins.toJSON {
              inherit host;
              http =
                builtins.replaceStrings [ "/var/log/nginx" ] [ "@RUNTIME@" ]
                  cfg.services.nginx.appendHttpConfig;
              server = vhost.extraConfig;
              origin = cfg.academy.backend.frontend;
              allowOtherOrigins = host == "test";
              public = locations."^~ /skills/lesson-assets/".extraConfig;
              private = locations."^~ /_private-lesson-modules/".extraConfig;
            }
          );
          nginx = cfg.services.nginx.package;
        in
        ''
          python ${../scripts/test-private-lesson-headers.py} \
            --nginx ${nginx}/bin/nginx --mime-types ${nginx}/conf/mime.types \
            --fixture ${fixture} --output "$out/${host}.json"
        ''
      )
      [
        "test"
        "prod"
      ];
in
pkgs.runCommand "private-lesson-header-tests"
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
