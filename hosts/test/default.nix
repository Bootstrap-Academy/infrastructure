{ config, env, ... }:

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
      ip4 = env.host.test;
    };
  };

  deploy-sh.buildHost = "root@${env.host.prod}";
  deploy-sh.buildCache = "/persistent/cache/deploy-sh/test";

  users.users.root.openssh.authorizedKeys.keys = [ env.ssh-key.prod ];

  backup.targets = {
    box = {
      repository = "sftp://u381435@u381435.your-storagebox.de:23/backups/test";
      repositoryPasswordFile = config.sops.secrets."backup/box/repository-password".path;
      sshKeyFile = config.sops.secrets."ssh/private-key".path;
    };
  };

  sops.secrets = {
    "ssh/private-key".path = "/root/.ssh/id_ed25519";
    "backup/box/repository-password" = { };
  };
}
