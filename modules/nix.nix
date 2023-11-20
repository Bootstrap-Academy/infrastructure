{
  pkgs,
  nixpkgs,
  ...
}: {
  nix = {
    nixPath = ["nixpkgs=${nixpkgs}"];
    gc = {
      automatic = true;
      dates = "03:30";
      options = "--delete-older-than 7d";
    };
    settings = {
      auto-optimise-store = true;
      experimental-features = ["nix-command" "flakes" "repl-flake"];
    };
    registry = {
      nixpkgs = {
        from = {
          id = "nixpkgs";
          type = "indirect";
        };
        exact = true;
        flake = nixpkgs;
      };
    };
  };

  system.activationScripts.nvd-diff = ''
    if old_system=$(readlink /run/current-system); then
      ${pkgs.nvd}/bin/nvd --color=always --nix-bin-dir=/run/current-system/sw/bin/ diff $old_system $systemConfig
    fi
    if [[ -e /run/booted-system ]] && ! ${pkgs.diffutils}/bin/diff <(readlink /run/booted-system/{initrd,kernel,kernel-modules}) <(readlink $systemConfig/{initrd,kernel,kernel-modules}); then
      echo -e "\033[1m==> REBOOT REQUIRED! \033[0m"
    fi
  '';

  environment.shellAliases = {
    needrestart = "diff <(readlink /run/booted-system/{initrd,kernel,kernel-modules}) <(readlink /run/current-system/{initrd,kernel,kernel-modules})";
    findport = pkgs.writeShellScript "findport.sh" ''
      port=''${1:-8000}
      proto=''${2:-tcp}
      while ss -Hlnp --$proto sport $port | grep .; do
        port=$((port+1))
      done
      echo "Port $port/$proto is not in use."
    '';
  };

  system.stateVersion = "23.11";
}
