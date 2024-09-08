{
  services.openssh.hostKeys = [
    {
      type = "ed25519";
      path = "/persistent/cache/ssh/ssh_host_ed25519_key";
    }
  ];

  sops.secrets."ssh/private-key" = {
    path = "/root/.ssh/id_ed25519";
  };
}
