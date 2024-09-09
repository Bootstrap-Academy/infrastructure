{
  config,
  nfnix,
  ...
}: {
  networking.firewall.enable = false;
  networking.nftables.enable = true;
  networking.nftables.ruleset = let
    inherit (nfnix.lib) mkRuleset vmap default_input default_forward allow_icmp_pings;

    wireguardNet = "10.23.1.0/24";
  in
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
              ${config.networking.networks.public.dev} = "jump input_public";
              ${config.networking.networks.private.internal.dev} = "jump input_internal";
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
            "iifname wg0 oifname ${config.networking.networks.private.internal.dev} accept"
          ];
        };

        chains.input_public = {
          policy = "drop";
          rules = [
            allow_icmp_pings

            # allow wireguard
            "udp dport 51820 accept"

            # allow nginx
            "tcp dport { 80, 443 } accept"
          ];
        };

        chains.input_internal = {
          policy = "drop";
          rules = [
            allow_icmp_pings

            # allow dns
            "tcp dport 53 accept"
            "udp dport 53 accept"

            # allow glitchtip
            "tcp dport { 80, 443 } accept"
          ];
        };

        chains.input_wireguard.policy = "accept";
      };
    };
}
