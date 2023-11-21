{
  imports = [
    ./hardware-configuration.nix
    ./networking.nix
    ./ssh.nix
  ];

  deploy-sh.targetHost = "root@10.23.0.3";
  deploy-sh.buildHost = "root@10.23.0.2";
}
