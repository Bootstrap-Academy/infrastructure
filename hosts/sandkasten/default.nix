{env, ...}: {
  imports = [
    ./hardware-configuration.nix
    ./networking.nix
    ./sandkasten.nix
    ./ssh.nix
  ];

  deploy-sh.buildHost = "root@${env.servers.academy.net.private.ip4}";
}
