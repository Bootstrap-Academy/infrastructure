{ lib, ... }:
{
  imports = [
    ./nginx.nix
    ./postgresql.nix
    ./redis.nix
  ];

  options.academy.backend = {
    enable = lib.mkEnableOption "Bootstrap Academy Backend";
    name = lib.mkOption { type = lib.types.str; };
    domain = lib.mkOption { type = lib.types.str; };
    frontend = lib.mkOption { type = lib.types.str; };
    protectInternalEndpoints = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    corsOrigins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };

    common = {
      environmentFiles = lib.mkOption { type = lib.types.listOf lib.types.path; };

      environment = lib.mkOption { type = lib.types.attrsOf lib.types.str; };
    };

    microservices = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            port = lib.mkOption { type = lib.types.port; };

            database = lib.mkOption {
              type = lib.types.nullOr (
                lib.types.submodule {
                  options = {
                    passwordFile = lib.mkOption {
                      type = lib.types.nullOr lib.types.path;
                      default = null;
                    };
                  };
                }
              );
            };

            redis.database = lib.mkOption { type = lib.types.ints.unsigned; };
          };
        }
      );
      default = { };
    };
  };

  config = { };
}
