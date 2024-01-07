{config, ...}: {
  users.mutableUsers = false;

  users.users.root.hashedPasswordFile = config.sops.secrets."users/root/password".path;

  sops.secrets."users/root/password".neededForUsers = true;
}
