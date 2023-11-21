{env, ...}: {
  networking.interfaces.${env.servers.prod.dev.public} = {
    ipv6.addresses = [
      {
        address = env.servers.prod.net.public.ip6;
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
