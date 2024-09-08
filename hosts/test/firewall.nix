{
  config,
  nfnix,
  ...
}: {
  networking.firewall.enable = false;
  networking.nftables.enable = true;
  networking.nftables.ruleset = let
    inherit (nfnix.lib) mkRuleset vmap default_input allow_icmp_pings;

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
            }}"
          ];
        };

        chains.input_public = {
          policy = "drop";
          rules = [
            allow_icmp_pings

            # allow nginx
            "tcp dport { 80, 443 } accept"
          ];
        };

        chains.input_internal = {
          policy = "drop";
          rules = [
            allow_icmp_pings

            "ip saddr ${wireguardNet} jump input_wireguard"

            # allow nginx
            "tcp dport { 80, 443 } accept"
          ];
        };

        chains.input_wireguard.policy = "accept";
      };
    };
}
