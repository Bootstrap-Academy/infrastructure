{
  dnscontrol,
  inputs,
  mkShell,
  nixos-anywhere,
  sops,
  ssh-to-age,
  stdenv,
}:

mkShell {
  packages = builtins.attrValues {
    inherit
      dnscontrol
      nixos-anywhere
      sops
      ssh-to-age
      ;

    deploy-sh = inputs.deploy-sh.packages.${stdenv.hostPlatform.system}.default;
  };
}
