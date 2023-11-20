{
  imports = [
    ./hardware-configuration.nix
    ./networking.nix
  ];

  deploy.host = "root@157.90.144.125";
}
