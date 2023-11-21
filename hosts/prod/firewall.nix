{
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
              ${server.dev.wireguard} = "jump input_wireguard";
            }}"
          ];
        };

        chains.forward = {
          type = "filter";
          hook = "forward";
          policy = "drop";
          rules = [
            default_forward
            "iifname ${server.dev.wireguard} oifname ${server.dev.private} accept"
          ];
        };

        chains.input_public = {
          policy = "drop";
          rules = [
            allow_icmp_pings

            # allow wireguard
            "udp dport ${toString server.wireguard.port} accept"
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
            "ip saddr ${env.net.internal.wireguard.net4} oifname ${server.dev.private} masquerade"
          ];
        };
      };
    };
}
