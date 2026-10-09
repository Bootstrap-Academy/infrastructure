{ config, env, ... }:

{
  imports = [
    ./attic.nix
    ./backend
    ./dns.nix
    ./firewall.nix
    ./glitchtip.nix
    ./grafana.nix
    ./morpheushelper
    ./nginx.nix
    ./restic.nix
    ./wireguard.nix
  ];

  # Normal production operation after the coordinated release is admitted.
  academy.releaseHold = false;

  filesystems.defaultLayout = true;

  networking.networks = {
    public = {
      dev = "enp1s0";
      ip4 = "49.13.80.22";
      ip6 = "2a01:4f8:c17:ad51::";
    };
    private.internal = {
      dev = "enp7s0";
      ip4 = env.host.prod;
    };
  };

  backup.targets = {
    box = {
      repository = "sftp://u381435@u381435.your-storagebox.de:23/backups/prod";
      repositoryPasswordFile = config.sops.secrets."backup/box/repository-password".path;
      sshKeyFile = config.sops.secrets."ssh/private-key".path;
    };
  };

  programs.ssh.knownHosts = {
    ${env.host.sandkasten}.publicKey =
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ9cuV9YpdIQ3jowOPGOL8Y+a6zW7+2YjCOr0b7RQskn";
    ${env.host.test}.publicKey =
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEvpmCYjNbdJ+TsrwagVGfu6pTNQrlvg9vZuKh9Xr/J8";
  };

  sops.secrets = {
    "ssh/private-key".path = "/root/.ssh/id_ed25519";
    "backup/box/repository-password" = { };
  };
}
