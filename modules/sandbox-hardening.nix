{
  config,
  lib,
  pkgs,
  sandkasten,
  ...
}:

let
  cfg = config.academy.sandboxHardening;
  programs = config.services.sandkasten.settings.programs_dir;
  delegatedNsjail = pkgs.writeShellScriptBin "nsjail" ''
    set -euo pipefail
    exec ${lib.getExe pkgs.nsjail} \
      --cgroupv2_mount /sys/fs/cgroup/system.slice/sandkasten.service "$@"
  '';
in
{
  imports = [ sandkasten.nixosModules.default ];

  options.academy.sandboxHardening = {
    enable = lib.mkEnableOption "unprivileged sandbox execution with a bounded artifact cache";
    cacheMiB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 512;
      description = "Maximum combined size of cached compiler artifacts and program metadata in MiB.";
    };
    cacheInodes = lib.mkOption {
      type = lib.types.ints.positive;
      default = 32768;
      description = "Maximum combined number of files and directories in the program cache.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.sandkasten.enable;
        message = "Sandbox hardening requires services.sandkasten.enable.";
      }
      {
        assertion = config.services.sandkasten.settings.use_cgroup;
        message = "Sandbox hardening requires cgroup memory and process limits.";
      }
      {
        assertion = programs == "/var/lib/sandkasten/programs";
        message = "The bounded sandbox cache must stay inside the service state directory.";
      }
    ];

    users.groups.academy-sandbox = { };
    users.users.academy-sandbox = {
      isSystemUser = true;
      group = "academy-sandbox";
      description = "Unprivileged code sandbox supervisor";
    };

    services.sandkasten.nsjailPackage = delegatedNsjail;
    services.sandkasten.settings.use_cgroup = lib.mkDefault true;

    systemd.mounts = [
      {
        what = "tmpfs";
        where = programs;
        type = "tmpfs";
        before = [ "sandkasten.service" ];
        options = lib.concatStringsSep "," [
          "size=${toString cfg.cacheMiB}M"
          "nr_inodes=${toString cfg.cacheInodes}"
          "mode=0700"
          "uid=academy-sandbox"
          "gid=academy-sandbox"
          "nodev"
          "nosuid"
        ];
      }
    ];

    systemd.services.sandkasten = {
      requires = [ "var-lib-sandkasten-programs.mount" ];
      after = [ "var-lib-sandkasten-programs.mount" ];
      serviceConfig = {
        User = "academy-sandbox";
        Group = "academy-sandbox";
        StateDirectoryMode = "0700";
        RuntimeDirectoryMode = "0700";
        UMask = "0077";
        # systemd owns the privileged setup. NsJail manages only this subtree.
        Delegate = [
          "memory"
          "pids"
          "cpu"
        ];
        DelegateSubgroup = "supervisor";
        CapabilityBoundingSet = "";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [
          programs
          "/sys/fs/cgroup/system.slice/sandkasten.service"
        ];
        # Per-job memory/PID limits remain in NsJail; this covers their aggregate.
        MemoryMax = "4G";
        MemorySwapMax = 0;
        TasksMax = 1024;
      };
    };
  };
}
