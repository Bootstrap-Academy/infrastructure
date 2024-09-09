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

  deploy-sh.buildHost = "root@10.23.0.2";
  deploy-sh.buildCache = "/persistent/cache/deploy-sh/sandkasten";

  users.users.root.openssh.authorizedKeys.keys = [
    # prod
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINO51jmJDWrG6eDLk7l0bEw4154r0jnvPyqug2aAMv4M"
  ];
}
