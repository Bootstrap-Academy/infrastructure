{
  config,
  lib,
  ...
}:
lib.mkIf (config.filesystems.defaultLayout) {
  services.btrfs.autoScrub = {
    enable = true;
    interval = "03:20";
    fileSystems = [
      "/nix"
    ];
  };
}
