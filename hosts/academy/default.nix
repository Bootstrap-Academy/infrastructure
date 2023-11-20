{
  imports = [
    ./firewall.nix
    ./hardware-configuration.nix
    ./networking.nix
    ./wireguard.nix
  ];

  deploy.host = "root@10.23.0.2";

  sops.defaultSopsFile = ./secrets.yml;
}
