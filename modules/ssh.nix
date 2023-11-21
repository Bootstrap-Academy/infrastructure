{
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  users.users.root.openssh.authorizedKeys.keys = [
    # Defelo
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID0+Dd5FL6zKIxkjJaOb+/7fp5YtePkDdGasYESAl0br"
    "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBCqDljgWk+qK1pHdTZdgFgXcMdizAz7OmGR9fx0yROQ6+Ja7zUxnAxOi0ijOk8HLWrZ9xu/TqKPvF29hndCEJtg="

    # Nico
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE2k27mRS2MmZ+b0QqF7eGonD8pEQE3lqFTLUHkUDK3X"
  ];

  programs.ssh.knownHosts = {
    "10.23.0.2".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDICX5+RkzRMCwFqAbGrWOTPTsz53/7byvp6GGcvKQbV";
    "10.23.0.3".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN0OY+9GYyDhQvaS1jCLKU7J6FA6BnsYmrFbmBguqYPE";
  };
}
