{
  lib,
  server,
  ...
}: {
  networking = {
    interfaces = lib.mkIf (server ? "dev" && server.dev ? "public" && server.net.public ? "ip6") {
      ${server.dev.public} = {
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
      };
    };
    nameservers = [
      "1.1.1.1"
      "1.0.0.1"
      "2606:4700:4700::1111"
      "2606:4700:4700::1001"
    ];
  };
}
