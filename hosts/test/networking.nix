{env, ...}: {
  networking = {
    useDHCP = false;
    dhcpcd.enable = false;

    interfaces =
      {
        "enp1s0" =
          {
            ipv4.addresses = [
              {
                address = "49.13.123.1";
                prefixLength = 32;
              }
            ];
            ipv4.routes = [
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
          }
          // {
            ipv6.addresses = [
              {
                address = "2a01:4f8:c013:5e5f::";
                prefixLength = 64;
              }
            ];
            ipv6.routes = [
              {
                address = "::";
                prefixLength = 0;
                via = "fe80::1";
              }
            ];
          };
      }
      // {
        "enp7s0" = {
          ipv4.addresses = [
            {
              address = "10.23.0.4";
              prefixLength = 32;
            }
          ];
          ipv4.routes = [
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
      };

    nameservers = [env.servers.prod.net.private.ip4];
  };
}
