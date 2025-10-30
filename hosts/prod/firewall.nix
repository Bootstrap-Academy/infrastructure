{
  config,
  env,
  lib,
  nfnix,
  ...
}:

let
  inherit (nfnix.lib) vmap;

  mkList = lib.concatStringsSep ", ";

  allow_http = [
    "tcp dport { 80, 443 } accept"
    "udp dport 443 accept"
  ];

  allow_dns = [
    "tcp dport 53 accept"
    "udp dport 53 accept"
  ];
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
              ${config.networking.networks.public.dev} = "jump input_public";
              ${config.networking.networks.private.internal.dev} = "jump input_internal";
              "wg0" = "jump input_wireguard";
            }
          }"
        ];
      };

      chains.forward = {
        type = "filter";
        hook = "forward";
        policy = "drop";
        defaultRules.enable = true;
        rules = [ "iifname wg0 oifname ${config.networking.networks.private.internal.dev} accept" ];
      };

      chains.input_public = {
        policy = "drop";
        defaultRules.icmp_pings = true;
        rules = [
          # allow wireguard
          "udp dport 51820 accept"

          allow_http
        ];
      };

      chains.input_internal = {
        policy = "drop";
        defaultRules.icmp_pings = true;
        rules = [
          allow_dns
          allow_http
        ];
      };

      chains.input_wireguard = {
        policy = "drop";
        defaultRules.icmp_pings = true;
        rules = [
          "ip saddr { ${mkList env.wg.admins} } accept"

          allow_dns
          allow_http
        ];
      };
    };
  };

  boot.kernel.sysctl."net.ipv4.conf.all.forwarding" = true;
}
