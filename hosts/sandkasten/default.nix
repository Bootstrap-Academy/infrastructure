{env, ...}: {
  imports = [
    ./hardware-configuration.nix
    ./sandkasten.nix
    ./ssh.nix
  ];

  deploy-sh.buildHost = "root@${env.servers.prod.net.private.ip4}";
}
