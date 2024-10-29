{config, ...}: {
  imports = [
    ./backend
    ./buildbot.nix
    ./dns.nix
    ./docker-images.nix
    ./firewall.nix
    ./glitchtip.nix
    ./harmonia.nix
    ./morpheushelper
    ./nginx.nix
    ./restic.nix
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

  backup.targets = {
    box = {
      repository = "sftp://u381435@u381435.your-storagebox.de:23/backups/prod";
      repositoryPasswordFile = config.sops.secrets."backup/box/repository-password".path;
      sshKeyFile = config.sops.secrets."ssh/private-key".path;
    };
    defelo = {
      repository = "rest:https://backup.defelo.de/academy-prod";
      repositoryPasswordFile = config.sops.secrets."backup/defelo/repository-password".path;
      environmentFile = config.sops.templates."backup/defelo".path;
    };
  };

  networking.hosts."10.23.1.2" = ["backup.defelo.de"];

  programs.ssh.knownHosts = {
    "10.23.0.3".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ9cuV9YpdIQ3jowOPGOL8Y+a6zW7+2YjCOr0b7RQskn";
    "10.23.0.4".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEvpmCYjNbdJ+TsrwagVGfu6pTNQrlvg9vZuKh9Xr/J8";
  };

  sops = {
    secrets = {
      "ssh/private-key".path = "/root/.ssh/id_ed25519";
      "backup/box/repository-password" = {};
      "backup/defelo/repository-password" = {};
      "backup/defelo/rest-password" = {};
    };
    templates = {
      "backup/defelo".content = ''
        RESTIC_REST_USERNAME=academy-prod
        RESTIC_REST_PASSWORD=${config.sops.placeholder."backup/defelo/rest-password"}
      '';
    };
  };
}
