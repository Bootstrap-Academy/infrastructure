pkgs: let
  mkScripts = builtins.mapAttrs (name: deps:
    pkgs.stdenvNoCC.mkDerivation {
      inherit name;
      nativeBuildInputs = [pkgs.makeWrapper];
      unpackPhase = "true";
      installPhase = ''
        install -DT ${./${name}.sh} $out/bin/${name}
      '';
      postFixup = ''
        wrapProgram $out/bin/${name} --set PATH ${pkgs.lib.makeBinPath deps}
      '';
    });
  scripts = mkScripts {
    update-docker = with pkgs; [
      coreutils
      skopeo
    ];
  };
in
  scripts
