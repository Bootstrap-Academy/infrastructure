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
  scripts = with pkgs;
    mkScripts {
      update = [
        nix
        git
      ];
      mkpw = [
        coreutils
        xkcdpass
        mkpasswd
      ];
      mkht = [
        coreutils
        pwgen
        apacheHttpd
      ];
      update-docker = [
        coreutils
        skopeo
      ];
    };
in
  scripts
