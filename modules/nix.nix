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
        "https://sandkasten.cachix.org"
        "https://academy-backend.cachix.org"
        "https://cache.bootstrap.academy"
      ];
      trusted-public-keys = [
        "bootstrap-academy.cachix.org-1:QoTxaO9Xw868/oefU7MrrkzrbFH9sUCJwWbIqsLCjxs="
        "sandkasten.cachix.org-1:Pa7qfdlx7bZkko+ojaaEG9pyziZkaru9v4TfcioqNZw="
        "academy-backend.cachix.org-1:MxmjN6hjaiGdi42M6evdALWj5hHOyUAQTEgKvm+J0Ow="
        "cache.bootstrap.academy-1:unYr62tCwkIIohOUTXowIvzdqOl+0DlJNfYjEOZxdFE="
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
