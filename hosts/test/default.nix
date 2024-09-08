{
  imports = [
    ./backend
    ./boot.nix
    ./filesystems.nix
    ./firewall.nix
    ./networking.nix
    ./ssh.nix
    ./users.nix
  ];

  deploy-sh.targetHost = "root@10.23.0.4";

  sops.defaultSopsFile = ./secrets.yml;
}
