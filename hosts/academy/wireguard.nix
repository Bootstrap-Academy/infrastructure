{config, ...}: {
  networking.wireguard = {
    enable = true;
    interfaces.wg0 = {
      privateKeyFile = config.sops.secrets."wireguard/private-key".path;
      listenPort = 51820;
      ips = ["10.23.1.1/24"];
      peers = [
        {
          publicKey = "1g/V66LITNSzZD0DDIKt4l3u8/yOGYEOtcArAXMvHyQ=";
          presharedKeyFile = config.sops.secrets."wireguard/psk/defelo".path;
          allowedIPs = ["10.23.1.2/32"];
        }
      ];
    };
  };

  boot.kernel.sysctl."net.ipv4.conf.all.forwarding" = true;

  sops.secrets = {
    "wireguard/private-key" = {};
    "wireguard/psk/defelo" = {};
  };
}
