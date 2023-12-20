{
  lib,
  server,
  env,
  ...
}: {
  networking = {
    useDHCP = false;
    dhcpcd.enable = false;

    interfaces =
      lib.optionalAttrs (server ? "dev" && server.dev ? "public") {
        ${server.dev.public} =
          lib.optionalAttrs (server.net.public ? "ip4") {
            ipv4.addresses = [
              {
                address = server.net.public.ip4;
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
          // (lib.optionalAttrs (server.net.public ? "ip6") {
            ipv6.addresses = [
              {
                address = server.net.public.ip6;
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
          });
      }
      // (lib.optionalAttrs (server ? "dev" && server.dev ? "private") {
        ${server.dev.private} = {
          ipv4.addresses = [
            {
              address = server.net.private.ip4;
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
      });

    nameservers = [env.servers.prod.net.private.ip4];
  };
}
