{
  imports = [
    ./firewall.nix
    ./hardware-configuration.nix
    ./networking.nix
    ./ssh.nix
    ./wireguard.nix
  ];

  deploy-sh.targetHost = "root@10.23.0.2";

  sops.defaultSopsFile = ./secrets.yml;
}
