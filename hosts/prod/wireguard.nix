{
  config,
  lib,
  pkgs,
  ...
}:

{
  systemd.network = {
    netdevs."50-wg0" = {
      netdevConfig = {
        Kind = "wireguard";
        Name = "wg0";
      };
      wireguardConfig = {
        # public key: ZqV0pq88MfVkPR91YoSMTnUAwu0/4zvsAc9mkDHTAQM=
        PrivateKeyFile = config.sops.secrets."wireguard/private-key".path;
        ListenPort = 51820;
        RouteTable = "main";
      };
      wireguardPeers = [
        {
          # defelo
          PublicKey = "m247NX1GQVhM0+H/TNtZ7shEMy+nC1Z7C/NFYBjNFn4=";
          PresharedKeyFile = config.sops.secrets."wireguard/psk/defelo".path;
          AllowedIPs = [ "10.23.1.2/32" ];
        }
        {
          # nico-p14s
          PublicKey = "EtC01X70ExI7Kvrp5tzE8wWlcbKD/QHg6wIvUB5ewQI=";
          PresharedKeyFile = config.sops.secrets."wireguard/psk/nico-p14s".path;
          AllowedIPs = [ "10.23.1.3/32" ];
        }
        {
          # nico-prod
          PublicKey = "PrSCG2vuAiHKnB3AJm1ii6T2LHaB8ZRu8GinjPGfXEc=";
          PresharedKeyFile = config.sops.secrets."wireguard/psk/nico-prod".path;
          AllowedIPs = [ "10.23.1.4/32" ];
        }
      ];
    };
    networks."50-wg0" = {
      matchConfig.Name = "wg0";
      address = [ "10.23.1.1/24" ];
    };
  };

  environment.systemPackages = with pkgs; [ wireguard-tools ];

  sops.secrets = lib.genAttrs [
    "wireguard/private-key"
    "wireguard/psk/defelo"
    "wireguard/psk/nico-p14s"
    "wireguard/psk/nico-prod"
  ] (lib.const { owner = "systemd-network"; });
}
