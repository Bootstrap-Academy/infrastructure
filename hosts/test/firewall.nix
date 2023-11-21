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
              ${server.dev.public} = "jump input_public";
              ${server.dev.private} = "jump input_private";
            }}"
          ];
        };

        chains.input_public = {
          policy = "drop";
          rules = [
            allow_icmp_pings
          ];
        };

        chains.input_private = {
          policy = "drop";
          rules = [
            allow_icmp_pings

            # allow ssh
            "ip saddr ${env.servers.prod.net.private.ip4} tcp dport 22 accept"
          ];
        };
      };
    };
}
