{
  config,
  lib,
  pkgs,
  ...
}: let
  dockerImages = builtins.mapAttrs (_: x: x.image) config.dockerImages;

  fetch-script = pkgs.writeShellApplication {
    name = "fetch-docker-images";
    runtimeInputs = with pkgs; [nix-prefetch-docker alejandra];
    text = ''
      set -e
      exec > >(alejandra --quiet)
      echo '{dockerImages={'
      fetch() { ( echo "$1.meta="; nix-prefetch-docker "$2" "''${3:-latest}"; echo ';' ) }
      trap "echo '};}'" EXIT
      ${builtins.concatStringsSep "\n" (lib.mapAttrsToList (name: value: "fetch ${name} ${builtins.replaceStrings [":"] [" "] value}") dockerImages)}
    '';
  };
in {
  options = {
    dockerImages = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({config, ...}: {
        options = {
          meta = lib.mkOption {readOnly = true;};
          image = lib.mkOption {readOnly = true;};
          imageFile = lib.mkOption {readOnly = true;};
          mkContainer = lib.mkOption {readOnly = true;};
        };
        config = {
          image = "${config.meta.finalImageName}:${config.meta.finalImageTag}";
          imageFile = pkgs.dockerTools.pullImage config.meta;
          mkContainer = attrs: {inherit (config) image imageFile;} // attrs;
        };
      }));
      default = {};
    };
  };

  config = lib.mkIf (config.dockerImages != {}) {
    environment.systemPackages = [fetch-script];
  };
}
