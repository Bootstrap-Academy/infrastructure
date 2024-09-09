{
  config,
  lib,
  name,
  ...
}: {
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
      type = lib.types.attrsOf (lib.types.submodule {
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
      });
      default = {};
    };
  };

  config = {
    networking = {
      hostName = name;

      nameservers = [
        "10.23.0.2"
      ];

      useDHCP = false;
      dhcpcd.enable = false;

      interfaces = let
        inherit (config.networking.networks) public;

        public4 = lib.mkIf (public.dev != null && public.ip4 != null) {
          ${public.dev}.ipv4 = {
            addresses = [
              {
                address = public.ip4;
                prefixLength = 32;
              }
            ];
            routes = [
              {
                address = "172.31.1.1";
                prefixLength = 32;
              }
              {
                address = "0.0.0.0";
                prefixLength = 0;
                via = "172.31.1.1";
              }
            ];
          };
        };

        public6 = lib.mkIf (public.dev != null && public.ip6 != null) {
          ${public.dev}.ipv6 = {
            addresses = [
              {
                address = public.ip6;
                prefixLength = 64;
              }
            ];
            routes = [
              {
                address = "::";
                prefixLength = 0;
                via = "fe80::1";
              }
            ];
          };
        };

        private =
          lib.mapAttrsToList (name: private: {
            ${private.dev}.ipv4 = {
              addresses = [
                {
                  address = private.ip4;
                  prefixLength = 32;
                }
              ];
              routes = [
                {
                  address = "10.23.0.1";
                  prefixLength = 32;
                }
                {
                  address = "10.23.0.0";
                  prefixLength = 23;
                  via = "10.23.0.1";
                }
              ];
            };
          })
          config.networking.networks.private;
      in
        lib.mkMerge ([public4 public6] ++ private);
    };
  };
}
