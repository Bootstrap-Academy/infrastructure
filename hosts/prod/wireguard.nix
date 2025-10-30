{
  config,
  env,
  lib,
  pkgs,
  ...
}:

let
  peers = {
    defelo = "m247NX1GQVhM0+H/TNtZ7shEMy+nC1Z7C/NFYBjNFn4=";
    nico-p14s = "EtC01X70ExI7Kvrp5tzE8wWlcbKD/QHg6wIvUB5ewQI=";
    nico-prod = "PrSCG2vuAiHKnB3AJm1ii6T2LHaB8ZRu8GinjPGfXEc=";
    morpheus = "9KenEdGlpX3kmlNRSk4tUgAwQjokbsGDI7Oglw40JT8=";
  };
in

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
      wireguardPeers = lib.mapAttrsToList (name: public_key: {
        PublicKey = public_key;
        PresharedKeyFile = config.sops.secrets."wireguard/psk/${name}".path;
        AllowedIPs = [ "${env.wg.${name}}/32" ];
      }) peers;
    };
    networks."50-wg0" = {
      matchConfig.Name = "wg0";
      address = [ "10.23.1.1/24" ];
    };
  };

  environment.systemPackages = with pkgs; [ wireguard-tools ];

  sops.secrets = lib.genAttrs (
    [ "wireguard/private-key" ] ++ lib.mapAttrsToList (name: _: "wireguard/psk/${name}") peers
  ) (lib.const { owner = "systemd-network"; });
}
