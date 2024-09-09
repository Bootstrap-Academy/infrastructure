{
  config,
  lib,
  ...
}: {
  options.filesystems = {
    defaultLayout = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf config.filesystems.defaultLayout {
    disko.devices = {
      disk.sda = {
        type = "disk";
        device = "/dev/sda";

        content = {
          type = "gpt";

          partitions = {
            mbr = {
              size = "1M";
              type = "EF02";
              priority = 0;
            };

            root = {
              size = "100%";
              priority = 1;

              content = {
                type = "btrfs";
                extraArgs = ["-f"];
                subvolumes = {
                  "/@boot" = {
                    mountpoint = "/boot";
                    mountOptions = ["noatime" "compress=zstd"];
                  };
                  "/@nix" = {
                    mountpoint = "/nix";
                    mountOptions = ["noatime" "compress=zstd"];
                  };
                  "/@data" = {
                    mountpoint = "/persistent/data";
                    mountOptions = ["noatime" "compress=zstd"];
                  };
                  "/@cache" = {
                    mountpoint = "/persistent/cache";
                    mountOptions = ["noatime" "compress=zstd"];
                  };
                  "/@data/.snapshots" = {};
                  "/@cache/.snapshots" = {};
                };
              };
            };
          };
        };
      };

      nodev."/" = {
        fsType = "tmpfs";
        mountOptions = ["defaults" "mode=755" "size=100%"];
      };
    };

    fileSystems."/persistent/data".neededForBoot = true;
    fileSystems."/persistent/cache".neededForBoot = true;

    environment.persistence."/persistent/cache" = {
      directories = [
        "/var/lib/nixos"
        "/var/lib/systemd/timers"
        "/var/log"
      ];
      files = [
        "/etc/machine-id"
      ];
    };
  };
}
