{
  lib,
  name,
  sops-nix,
  ...
}: let
  file = ../hosts/${name}/secrets.yml;
in {
  imports = [
    sops-nix.nixosModules.default
  ];

  sops.defaultSopsFile = lib.mkIf (builtins.pathExists file) file;
}
