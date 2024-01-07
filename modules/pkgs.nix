{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    dig
    duf
    htop
    ncdu
    neovim
    wget
  ];

  environment.shellAliases.findport = pkgs.writeShellScript "findport.sh" ''
    port=''${1:-8000}
    proto=''${2:-tcp}
    while ss -Hlnp --$proto sport $port | grep .; do
      port=$((port+1))
    done
    echo "Port $port/$proto is not in use."
  '';
}
