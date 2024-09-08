{
  lib,
  env,
  ...
}: {
  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = true;
    alwaysKeepRunning = true;
    settings = {
      no-hosts = true;
      no-resolv = true;
      server = [
        "1.1.1.1"
        "1.0.0.1"
        "2606:4700:4700::1111"
        "2606:4700:4700::1001"
      ];
      address =
        lib.flatten (lib.mapAttrsToList (name: {
          net,
          domains ? [],
          ...
        }: let
          domains' = lib.optional (net ? "private") "${name}.internal.bootstrap.academy" ++ domains;
        in
          map (domain: [
            "/${domain}/" # clear AAAA records
            "/${domain}/${net.private.ip4}"
          ])
          domains')
        env.servers)
        ++ [
          "/api.test.bootstrap.academy/"
          "/api.test.bootstrap.academy/10.23.0.4"
          "/test.internal.bootstrap.academy/"
          "/test.internal.bootstrap.academy/10.23.0.4"
        ];
    };
  };
}
