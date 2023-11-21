{config, ...}: {
  networking.wireguard = {
    enable = true;
    interfaces.wg0 = {
      privateKeyFile = config.sops.secrets."wireguard/private-key".path;
      listenPort = 51820;
      ips = ["10.23.1.1/24"];
      peers = [
        {
          # Defelo
          publicKey = "1g/V66LITNSzZD0DDIKt4l3u8/yOGYEOtcArAXMvHyQ=";
          presharedKeyFile = config.sops.secrets."wireguard/psk/defelo".path;
          allowedIPs = ["10.23.1.2/32"];
        }
        {
          # Nico T480
          publicKey = "EtC01X70ExI7Kvrp5tzE8wWlcbKD/QHg6wIvUB5ewQI=";
          presharedKeyFile = config.sops.secrets."wireguard/psk/nico".path;
          allowedIPs = ["10.23.1.3/32"];
        }
      ];
    };
  };

  boot.kernel.sysctl."net.ipv4.conf.all.forwarding" = true;

  sops.secrets = {
    "wireguard/private-key" = {};
    "wireguard/psk/defelo" = {};
    "wireguard/psk/nico" = {};
  };
}
