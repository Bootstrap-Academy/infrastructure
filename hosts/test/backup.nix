{config, ...}: {
  backup = {
    enable = true;
    repo = "ssh://u381435@u381435.your-storagebox.de:23/./backups/test";
    passwordFile = config.sops.secrets."backup/password".path;
  };

  sops.secrets."backup/password" = {};
}
