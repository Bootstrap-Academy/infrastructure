{
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
    hostKeys = [
      {
        type = "ed25519";
        path = "/persistent/cache/ssh/ssh_host_ed25519_key";
      }
    ];
  };

  users.users.root.openssh.authorizedKeys.keys = [
    # defelo
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID0+Dd5FL6zKIxkjJaOb+/7fp5YtePkDdGasYESAl0br"
    "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBCqDljgWk+qK1pHdTZdgFgXcMdizAz7OmGR9fx0yROQ6+Ja7zUxnAxOi0ijOk8HLWrZ9xu/TqKPvF29hndCEJtg="

    # nico
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE2k27mRS2MmZ+b0QqF7eGonD8pEQE3lqFTLUHkUDK3X"
  ];

  programs.ssh.knownHosts = {
    "u381435.your-storagebox.de".publicKey =
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIICf9svRenC/PLKIL9nk6K/pxQgoiFC41wTNvoIncOxs";
  };
}
