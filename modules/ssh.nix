{
  lib,
  env,
  ...
}: {
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  users.users.root.openssh.authorizedKeys.keys = lib.flatten (builtins.attrValues env.sshKeys);

  programs.ssh.knownHosts = builtins.listToAttrs (map (server: {
    name = server.net.private.ip4;
    value = {
      publicKey = server.ssh.publicKey;
    };
  }) (builtins.attrValues env.servers));
}
