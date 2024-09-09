{config, ...}: {
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

  deploy-sh.buildHost = "root@10.23.0.2";
  deploy-sh.buildCache = "/persistent/cache/deploy-sh/test";

  users.users.root.openssh.authorizedKeys.keys = [
    # prod
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINO51jmJDWrG6eDLk7l0bEw4154r0jnvPyqug2aAMv4M"
  ];

  backup.targets = {
    box = {
      repository = "sftp://u381435@u381435.your-storagebox.de:23/backups/test";
      repositoryPasswordFile = config.sops.secrets."backup/box/repository-password".path;
      sshKeyFile = config.sops.secrets."ssh/private-key".path;
    };
  };

  sops.secrets = {
    "ssh/private-key".path = "/root/.ssh/id_ed25519";
    "backup/box/repository-password" = {};
  };
}
