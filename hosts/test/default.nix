{ config, env, ... }:

{
  imports = [
    ./backend
    ./firewall.nix
    ./sandbox.nix
  ];

  # Test services and maintenance timers use their normal startup after reboot.
  academy.releaseHold = false;

  monitoring.alerting = {
    enable = true;
    probes = {
      api = {
        url = "https://api.test.bootstrap.academy/health";
        module = "database";
      };
      skills.url = "https://api.test.bootstrap.academy/skills/skilltree";
      challenges.url = "https://api.test.bootstrap.academy/challenges/openapi.json";
      frontend.url = "https://test.bootstrap.academy/";
    };
  };
  environment.persistence."/persistent/data".directories = [
    "/var/lib/prometheus2"
    "/var/lib/alertmanager"
    "/var/lib/academy-backup-metrics"
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
