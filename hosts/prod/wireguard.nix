{
  config,
  lib,
  env,
  ...
}: {
  networking.wireguard = {
    enable = true;
    interfaces.${env.servers.prod.dev.wireguard} = {
      privateKeyFile = config.sops.secrets."wireguard/private-key".path;
      listenPort = env.servers.prod.wireguard.port;
      ips = ["${env.servers.prod.net.wireguard.ip4}/24"];
      peers =
        lib.mapAttrsToList (name: {
          publicKey,
          ip4,
        }: {
          inherit publicKey;
          presharedKeyFile = config.sops.secrets."wireguard/psk/${name}".path;
          allowedIPs = ["${ip4}/32"];
        })
        env.servers.prod.wireguard.peers;
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
    }) (builtins.attrNames env.servers.prod.wireguard.peers)));
}
