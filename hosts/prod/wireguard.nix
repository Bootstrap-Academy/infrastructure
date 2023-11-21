{
  config,
  lib,
  server,
  ...
}: {
  networking.wireguard = {
    enable = true;
    interfaces.${server.dev.wireguard} = {
      privateKeyFile = config.sops.secrets."wireguard/private-key".path;
      listenPort = server.wireguard.port;
      ips = ["${server.net.wireguard.ip4}/24"];
      peers =
        lib.mapAttrsToList (name: {
          publicKey,
          ip4,
        }: {
          inherit publicKey;
          presharedKeyFile = config.sops.secrets."wireguard/psk/${name}".path;
          allowedIPs = ["${ip4}/32"];
        })
        server.wireguard.peers;
    };
  };

  boot.kernel.sysctl."net.ipv4.conf.all.forwarding" = true;

  sops.secrets =
    {
      "wireguard/private-key" = {};
    }
    // (builtins.listToAttrs (map (name: {
      name = "wireguard/psk/${name}";
      value = {};
    }) (builtins.attrNames server.wireguard.peers)));
}
