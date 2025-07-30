{
  config,
  lib,
  name,
  ...
}:
{
  options.networking = {
    networks.public.ip4 = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    networks.public.ip6 = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    networks.public.dev = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };

    networks.private = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            ip4 = lib.mkOption {
              type = lib.types.str;
              default = null;
            };
            dev = lib.mkOption {
              type = lib.types.str;
              default = null;
            };
          };
        }
      );
      default = { };
    };
  };

  config = {
    networking = {
      hostName = name;

      nameservers = [ "10.23.0.2" ];

      useDHCP = false;
      dhcpcd.enable = false;
    };

    systemd.network =
      let
        inherit (config.networking.networks) public;
      in
      {
        enable = true;

        networks = {
          "10-wan" = lib.mkIf (public.dev != null) {
            matchConfig.Name = public.dev;
            address =
              lib.optionals (public.ip4 != null) [ "${public.ip4}/32" ]
              ++ lib.optionals (public.ip6 != null) [ "${public.ip6}/64" ];
            routes =
              lib.optionals (public.ip4 != null) [
                {
                  Gateway = "172.31.1.1";
                  GatewayOnLink = true;
                }
              ]
              ++ lib.optionals (public.ip6 != null) [ { Gateway = "fe80::1"; } ];
            linkConfig.RequiredForOnline = "routable";
          };
        }
        // lib.mapAttrs' (
          name: private:
          lib.nameValuePair "20-${name}" {
            matchConfig.Name = private.dev;
            address = lib.optionals (private.ip4 != null) [ "${private.ip4}/32" ];
            routes = lib.optionals (private.ip4 != null) [
              {
                Gateway = "10.23.0.1";
                GatewayOnLink = true;
                Destination = "10.23.0.0/23";
              }
            ];
            linkConfig.RequiredForOnline = "routable";
          }
        ) config.networking.networks.private;
      };
  };
}
