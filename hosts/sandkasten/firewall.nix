{ config, nfnix, ... }:
{
  networking.firewall.enable = false;
  networking.nftables.enable = true;
  networking.nftables.ruleset =
    let
      inherit (nfnix.lib)
        mkRuleset
        vmap
        default_input
        allow_icmp_pings
        ;

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
            "iifname ${
              vmap {
                ${config.networking.networks.private.internal.dev} = "jump input_private";
              }
            }"
          ];
        };

        chains.input_private = {
          policy = "drop";
          rules = [
            allow_icmp_pings

            "ip saddr ${wireguardNet} jump input_wireguard"

            # allow ssh from prod
            "ip saddr 10.23.0.2 tcp dport 22 accept"

            # allow sandkasten
            "tcp dport ${toString config.services.sandkasten.settings.port} accept"
          ];
        };

        chains.input_wireguard = {
          policy = "accept";
          rules = [ ];
        };
      };
    };
}
