{
  env,
  nfnix,
  ...
}: {
  networking.firewall.enable = false;
  networking.nftables.enable = true;
  networking.nftables.ruleset = let
    inherit (nfnix.lib) mkRuleset vmap default_input allow_icmp_pings;
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
              "enp1s0" = "jump input_public";
              "enp7s0" = "jump input_private";
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

        chains.input_private = {
          policy = "drop";
          rules = [
            allow_icmp_pings

            "ip saddr ${env.net.internal.wireguard.net4} jump input_wireguard"

            # allow nginx
            "tcp dport { 80, 443 } accept"
          ];
        };

        chains.input_wireguard.policy = "accept";
      };
    };
}
