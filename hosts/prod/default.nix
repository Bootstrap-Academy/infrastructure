{
  imports = [
    ./backend
    ./dns.nix
    ./docker-images.nix
    ./firewall.nix
    ./glitchtip.nix
    ./morpheushelper
    ./nginx.nix
    ./wireguard.nix
  ];

  filesystems.defaultLayout = true;

  networking.networks = {
    public = {
      dev = "enp1s0";
      ip4 = "49.13.80.22";
      ip6 = "2a01:4f8:c17:ad51::";
    };
    private.internal = {
      dev = "enp7s0";
      ip4 = "10.23.0.2";
    };
  };

  sops.secrets."ssh/private-key".path = "/root/.ssh/id_ed25519";
}
