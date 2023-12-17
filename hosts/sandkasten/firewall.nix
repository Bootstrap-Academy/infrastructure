{
  config,
  nfnix,
  env,
  server,
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
              ${server.dev.private} = "jump input_private";
            }}"
          ];
        };

        chains.input_private = {
          policy = "drop";
          rules = [
            allow_icmp_pings

            "ip saddr ${env.net.internal.wireguard.net4} jump input_wireguard"

            # allow sandkasten
            "tcp dport ${toString config.services.sandkasten.settings.port} accept"
          ];
        };

        chains.input_wireguard = {
          policy = "accept";
          rules = [];
        };
      };
    };
}
