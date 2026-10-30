{ pkgs-kernel, ... }:

{
  boot.loader = {
    grub.enable = true;
    timeout = 2;
  };

  console.enable = false;

  # The kernel comes from a newer nixos-26.05 revision than the rest of the system: 7.2.13 carries the
  # fix for CVE-2026-98432 (fixed in 7.2.10). Back to pkgs.linuxPackages_latest with the next nixpkgs update.
  boot.kernelPackages = pkgs-kernel.linuxPackages_7_2;

  security.lockKernelModules = true;
}
