{env, ...}: {
  networking.interfaces.${env.servers.test.dev.public} = {
    ipv6.addresses = [
      {
        address = env.servers.test.net.public.ip6;
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
