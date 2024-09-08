{
  imports = [
    ./backend
    ./firewall.nix
  ];

  filesystems.defaultLayout = true;

  networking.networks = {
    public = {
      dev = "enp1s0";
      ip4 = "49.13.123.1";
      ip6 = "2a01:4f8:c013:5e5f::";
    };
    private.internal = {
      dev = "enp7s0";
      ip4 = "10.23.0.4";
    };
  };

  sops.secrets."ssh/private-key".path = "/root/.ssh/id_ed25519";
}
