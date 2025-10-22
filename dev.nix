{
  deploy-sh,
  pkgs,
  self,
  system,
  ...
}:
pkgs.mkShell {
  packages =
    let
      update = pkgs.writeShellApplication {
        name = "update";
        runtimeInputs = builtins.attrValues { inherit (pkgs) nix git openssh; };
        text = ''
          if [[ $# -eq 0 ]]; then
            nix flake update --commit-lock-file
          else
            args=()
            for x in "$@"; do
              args+=(--update-input "$x")
            done
            nix flake lock "''${args[@]}" --commit-lock-file
          fi

          if [[ $# -eq 0 ]]; then
            ssh root@10.23.0.2 fetch-docker-images > hosts/prod/docker-images.nix
          fi
        '';
      };
    in
    builtins.attrValues {
      inherit (pkgs)
        sops
        ssh-to-age
        nixos-anywhere
        dnscontrol
        ;
    }
    ++ [
      deploy-sh.packages.${system}.default
      self.formatter.${system}

      update
    ];
}
