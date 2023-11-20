{
  config,
  nfnix,
  ...
}: {
  networking.firewall.enable = false;
  networking.nftables.enable = true;
  networking.nftables.ruleset = with nfnix.lib;
    mkRuleset {
      tables.filter = {
        family = "inet";

        chains.input = {
          type = "filter";
          hook = "input";
          policy = "drop";
          rules = [
            default_input
            "iif lo accept"
            "iifname ${vmap {
              "enp1s0" = "jump input_public";
              "wg0" = "jump input_wireguard";
            }}"
          ];
        };

        chains.forward = {
          type = "filter";
          hook = "forward";
          policy = "drop";
          rules = [
            default_forward
            "iifname wg0 oifname enp7s0 accept"
          ];
        };

        chains.input_public = {
          policy = "drop";
          rules = [
            allow_icmp_pings

            # allow wireguard
            "udp dport ${toString config.networking.wireguard.interfaces.wg0.listenPort} accept"
          ];
        };

        chains.input_wireguard = {
          policy = "accept";
          rules = [];
        };
      };

      tables.nat = {
        family = "inet";

        chains.postrouting = {
          type = "nat";
          hook = "postrouting";
          rules = [
            "ip saddr 10.23.1.0/24 oifname enp7s0 masquerade"
          ];
        };
      };
    };
}
