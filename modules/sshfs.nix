{
  config,
  lib,
  pkgs,
  ...
}: {
  options.services.sshfs = with lib; {
    mounts = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          host = mkOption {
            type = types.str;
          };

          port = mkOption {
            type = types.port;
            default = 22;
          };

          user = mkOption {
            type = types.str;
          };

          path = mkOption {
            type = types.str;
            default = "";
          };

          allowOther = mkOption {
            type = types.bool;
            default = false;
          };

          readOnly = mkOption {
            type = types.bool;
            default = false;
          };

          options = mkOption {
            type = types.listOf types.str;
            default = [];
          };
        };
      });
      default = {};
    };
  };

  config = let
    cfg = config.services.sshfs;
  in
    lib.mkIf (cfg.mounts != {}) {
      environment.systemPackages = [pkgs.sshfs];

      fileSystems =
        builtins.mapAttrs (_: {
          user,
          host,
          path,
          port,
          options,
          readOnly,
          allowOther,
        }: {
          fsType = "fuse.sshfs";
          device = "${user}@${host}:${path}";
          options =
            ["_netdev" "port=${toString port}"]
            ++ (lib.optional readOnly "ro")
            ++ (lib.optional allowOther "allow_other")
            ++ options;
        })
        cfg.mounts;
    };
}
