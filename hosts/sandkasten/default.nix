{ env, ... }:

{
  imports = [
    ./firewall.nix
    ./sandkasten.nix
  ];

  filesystems.defaultLayout = true;

  networking.networks = {
    private.internal = {
      dev = "enp7s0";
      ip4 = env.host.sandkasten;
    };
  };

  deploy-sh.buildHost = "root@${env.host.prod}";
  deploy-sh.buildCache = "/persistent/cache/deploy-sh/sandkasten";

  users.users.root.openssh.authorizedKeys.keys = [ env.ssh-key.prod ];
}
