{
  imports = [
    ./firewall.nix
    ./sandkasten.nix
  ];

  filesystems.defaultLayout = true;

  networking.networks = {
    private.internal = {
      dev = "enp7s0";
      ip4 = "10.23.0.3";
    };
  };

  deploy-sh.buildHost = null;
}
