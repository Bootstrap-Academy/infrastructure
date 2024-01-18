{lib, ...}: {
  imports = [
    ./nginx.nix
    ./postgresql.nix
    ./redis.nix
    ./scripts.nix
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
    protectInternalEndpoints = mkOption {
      type = types.bool;
      default = true;
    };
    corsOrigins = mkOption {
      type = types.listOf types.str;
      default = [];
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
                  type = types.nullOr types.path;
                  default = null;
                };
              };
            });
          };

          redis.database = mkOption {
            type = types.ints.unsigned;
          };
        };
      });
      default = {};
    };
  };

  config = {};
}
