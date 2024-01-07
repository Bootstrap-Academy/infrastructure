{env, ...}: {
  imports = [
    ./firewall.nix
    ./sandkasten.nix
    ./ssh.nix
  ];

  deploy-sh.buildHost = "root@${env.servers.prod.net.private.ip4}";
  deploy-sh.buildCache = "/var/cache/deploy-sh/sandkasten";
}
