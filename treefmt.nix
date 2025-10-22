{ lib, pkgs, ... }:

{
  tree-root-file = ".git/config";
  on-unmatched = "error";

  excludes = [
    ".envrc"
    "*.md"
    ".gitignore"
    "flake.lock"
    "hosts/*/hardware-configuration.nix"
    "hosts/*/secrets.yml"
  ];

  formatter.nixfmt = {
    command = lib.getExe pkgs.nixfmt-rfc-style;
    includes = [ "*.nix" ];
    options = [ "--strict" ];
  };

  formatter.prettier = {
    command = lib.getExe pkgs.nodePackages.prettier;
    includes = [
      "*.js"
      "*.json"
      "*.yaml"
      "*.yml"
    ];
    options = [ "--write" ];
  };
}
