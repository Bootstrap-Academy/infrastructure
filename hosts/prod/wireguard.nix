{ config, ... }:
{
  networking.wireguard = {
    enable = true;
    interfaces.wg0 = {
      # public key: ZqV0pq88MfVkPR91YoSMTnUAwu0/4zvsAc9mkDHTAQM=
      privateKeyFile = config.sops.secrets."wireguard/private-key".path;
      listenPort = 51820;
      ips = [ "10.23.1.1/24" ];
      peers = [
        {
          name = "defelo";
          publicKey = "m247NX1GQVhM0+H/TNtZ7shEMy+nC1Z7C/NFYBjNFn4=";
          presharedKeyFile = config.sops.secrets."wireguard/psk/defelo".path;
          allowedIPs = [ "10.23.1.2/32" ];
        }
        {
          name = "nico-p14s";
          publicKey = "EtC01X70ExI7Kvrp5tzE8wWlcbKD/QHg6wIvUB5ewQI=";
          presharedKeyFile = config.sops.secrets."wireguard/psk/nico-p14s".path;
          allowedIPs = [ "10.23.1.3/32" ];
        }
        {
          name = "nico-prod";
          publicKey = "PrSCG2vuAiHKnB3AJm1ii6T2LHaB8ZRu8GinjPGfXEc=";
          presharedKeyFile = config.sops.secrets."wireguard/psk/nico-prod".path;
          allowedIPs = [ "10.23.1.4/32" ];
        }
      ];
    };
  };

  boot.kernel.sysctl."net.ipv4.conf.all.forwarding" = true;

  sops.secrets = {
    "wireguard/private-key" = { };
    "wireguard/psk/defelo" = { };
    "wireguard/psk/nico-p14s" = { };
    "wireguard/psk/nico-prod" = { };
  };
}
