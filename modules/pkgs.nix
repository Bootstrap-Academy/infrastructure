{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    dig
    duf
    htop
    ncdu
    neovim
    wget
  ];
}
