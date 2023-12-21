{
  users.users.root.openssh.authorizedKeys.keys = [
    # prod
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINO51jmJDWrG6eDLk7l0bEw4154r0jnvPyqug2aAMv4M"
  ];

  sops.secrets."ssh/private-key" = {
    path = "/root/.ssh/id_ed25519";
  };
}
