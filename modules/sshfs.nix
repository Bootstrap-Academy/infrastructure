{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.services.sshfs = {
    mounts = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            host = lib.mkOption { type = lib.types.str; };

            port = lib.mkOption {
              type = lib.types.port;
              default = 22;
            };

            user = lib.mkOption { type = lib.types.str; };

            path = lib.mkOption {
              type = lib.types.str;
              default = "";
            };

            allowOther = lib.mkOption {
              type = lib.types.bool;
              default = false;
            };

            readOnly = lib.mkOption {
              type = lib.types.bool;
              default = false;
            };

            reconnect = lib.mkOption {
              type = lib.types.bool;
              default = true;
            };

            options = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
            };
          };
        }
      );
      default = { };
    };
  };

  config =
    let
      cfg = config.services.sshfs;
    in
    lib.mkIf (cfg.mounts != { }) {
      environment.systemPackages = [ pkgs.sshfs ];

      fileSystems = builtins.mapAttrs (
        _:
        {
          user,
          host,
          path,
          port,
          options,
          readOnly,
          allowOther,
          reconnect,
        }:
        {
          fsType = "fuse.sshfs";
          device = "${user}@${host}:${path}";
          options =
            [
              "_netdev"
              "port=${toString port}"
            ]
            ++ (lib.optional readOnly "ro")
            ++ (lib.optional allowOther "allow_other")
            ++ (lib.optional reconnect "reconnect")
            ++ options;
        }
      ) cfg.mounts;
    };
}
