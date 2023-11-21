{env, ...}: {
  networking.interfaces.${env.servers.academy.dev.public} = {
    ipv6.addresses = [
      {
        address = env.servers.academy.net.public.ip6;
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
