{
  imports = [
    ./hardware-configuration.nix
    ./networking.nix
  ];

  deploy.host = "root@10.23.0.3";
  deploy.remoteBuild = false;
}
