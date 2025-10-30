{
  config,
  env,
  nfnix,
  ...
}:

let
  inherit (nfnix.lib) vmap;
in

{
  imports = [ nfnix.nixosModules.default ];

  networking.firewall.enable = false;
  networking.nftables = {
    enable = true;
    flushRuleset = true;

    tables.filter = {
      family = "inet";

      chains.input = {
        type = "filter";
        hook = "input";
        policy = "drop";
        defaultRules.enable = true;
        rules = [
          "iifname ${
            vmap {
              ${config.networking.networks.private.internal.dev} = "jump input_private";
            }
          }"
        ];
      };

      chains.input_private = {
        policy = "drop";
        defaultRules.icmp_pings = true;
        rules = [
          "ip saddr ${env.net.wg} jump input_wireguard"

          # allow ssh from prod
          "ip saddr ${env.host.prod} tcp dport 22 accept"

          # allow sandkasten
          "tcp dport ${toString config.services.sandkasten.settings.port} accept"
        ];
      };

      chains.input_wireguard.policy = "accept";
    };
  };
}
