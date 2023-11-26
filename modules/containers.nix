{
  config,
  pkgs,
  lib,
  ...
}: {
  config = lib.mkIf (config.virtualisation.oci-containers.containers != {}) {
    virtualisation = {
      oci-containers.backend = "podman";
      podman = {
        enable = true;
        dockerCompat = true;
        dockerSocket.enable = true;
        autoPrune = {
          enable = true;
          dates = "daily";
          flags = ["--all"];
        };
      };
    };

    systemd.tmpfiles.rules = [
      "L+ /var/run/docker.sock - - - - /run/podman/podman.sock"
    ];

    environment.systemPackages = with pkgs; [ctop];
  };
}
