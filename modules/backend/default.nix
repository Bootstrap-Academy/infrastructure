{lib, ...}: {
  imports = [
    ./containers.nix
    ./nginx.nix
    ./postgresql.nix
    ./redis.nix
  ];

  options.academy.backend = with lib; {
    enable = mkEnableOption "Bootstrap Academy Backend";
    name = mkOption {
      type = types.str;
    };
    domain = mkOption {
      type = types.str;
    };
    frontend = mkOption {
      type = types.str;
    };

    common = {
      environmentFiles = mkOption {
        type = types.listOf types.path;
      };

      environment = mkOption {
        type = types.attrsOf types.str;
      };
    };

    microservices = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          port = mkOption {
            type = types.port;
          };

          database = mkOption {
            type = types.nullOr (types.submodule {
              options = {
                passwordFile = mkOption {
                  type = types.path;
                };
              };
            });
          };

          redis.database = mkOption {
            type = types.ints.unsigned;
          };

          container = mkOption {
            type = types.nullOr (types.submodule {
              options = {
                image = mkOption {
                  type = types.str;
                };

                environmentFiles = mkOption {
                  type = types.listOf types.path;
                };

                environment = mkOption {
                  type = types.attrsOf types.str;
                };
              };
            });
          };
        };
      });
    };
  };

  config = {};
}
