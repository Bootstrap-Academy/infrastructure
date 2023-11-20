{
  networking = {
    hostName = "academy";

    interfaces = {
      enp1s0 = {
        ipv6.addresses = [
          {
            address = "2a01:4f8:c012:a47b::";
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
  };
}
