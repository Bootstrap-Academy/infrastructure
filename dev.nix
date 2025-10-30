{ deploy-sh, pkgs, ... }:

pkgs.mkShell {
  packages = builtins.attrValues {
    inherit (pkgs)
      dnscontrol
      nixos-anywhere
      sops
      ssh-to-age
      ;

    deploy-sh = deploy-sh.packages.${pkgs.system}.default;
  };
}
