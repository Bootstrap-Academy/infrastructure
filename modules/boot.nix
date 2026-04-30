{ pkgs, ... }:

{
  boot.loader = {
    grub.enable = true;
    timeout = 2;
  };

  console.enable = false;

  boot.kernelPackages = pkgs.linuxPackages_latest;
}
