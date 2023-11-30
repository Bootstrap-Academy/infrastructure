{
  config,
  lib,
  ...
}: let
  setRootPassword = builtins.readDir ../hosts/${config.networking.hostName} ? "secrets.yml";
in {
  users.mutableUsers = false;

  users.users.root.hashedPasswordFile = lib.mkIf setRootPassword config.sops.secrets."users/root/password".path;

  sops.secrets."users/root/password" = lib.mkIf setRootPassword {neededForUsers = true;};
}
