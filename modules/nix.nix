{
  pkgs,
  nixpkgs,
  ...
}: {
  nix = {
    package = pkgs.nixVersions.latest;
    nixPath = ["nixpkgs=${nixpkgs}"];
    gc = {
      automatic = true;
      dates = "03:30";
      options = "--delete-older-than 7d";
    };
    settings = {
      auto-optimise-store = true;
      experimental-features = ["nix-command" "flakes"];
      substituters = [
        "https://bootstrap-academy.cachix.org"
        "https://attic.defelo.de/sandkasten"
        "https://cache.bootstrap.academy/academy"
      ];
      trusted-public-keys = [
        "bootstrap-academy.cachix.org-1:QoTxaO9Xw868/oefU7MrrkzrbFH9sUCJwWbIqsLCjxs="
        "sandkasten:U7kShJt9A6tZr4pZRAXHmRlxC3nmOGvfviPqKL7hROE="
        "academy:JU67oyd32Kzh7XFkUD/rZ6I3wVT8xMtgghwBvEINGus="
      ];
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

  environment.shellAliases.needrestart = "diff <(readlink /run/booted-system/{initrd,kernel,kernel-modules}) <(readlink /run/current-system/{initrd,kernel,kernel-modules})";

  system.stateVersion = "24.05";
}
