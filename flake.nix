{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    deploy-sh.url = "github:Defelo/deploy-sh";
    sops-nix.url = "github:Mic92/sops-nix";
    nfnix.url = "github:Defelo/nfnix";
    sandkasten.url = "github:Defelo/sandkasten";

    challenges-ms-develop.url = "github:Bootstrap-Academy/challenges-ms/develop";
  };

  outputs = {
    self,
    nixpkgs,
    deploy-sh,
    sops-nix,
    ...
  } @ inputs: let
    defaultSystems = [
      "x86_64-linux"
      "x86_64-darwin"
      "aarch64-linux"
      "aarch64-darwin"
    ];
    eachDefaultSystem = f:
      builtins.listToAttrs (map (system: {
          name = system;
          value = f system;
        })
        defaultSystems);
    env = import ./env.nix;
  in {
    nixosConfigurations = builtins.mapAttrs (name: server:
      nixpkgs.lib.nixosSystem {
        inherit (server) system;
        specialArgs =
          inputs
          // {
            inherit env server;
            docker-images = fromTOML (builtins.readFile ./docker-images.toml);
          };
        modules = [
          deploy-sh.nixosModules.default
          sops-nix.nixosModules.default
          ./hosts/${name}
          ./modules
          {
            networking.hostName = name;
            deploy-sh.targetHost = nixpkgs.lib.mkDefault "root@${server.net.private.ip4}";
            sops.defaultSopsFile = nixpkgs.lib.mkIf (builtins.readDir ./hosts/${name} ? "secrets.yml") ./hosts/${name}/secrets.yml;
          }
        ];
      })
    env.servers;
    deploy-sh.hosts = self.nixosConfigurations;
    devShells = eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
      scripts' = {
        update = ''
          if [[ $# -eq 0 ]]; then
            nix flake update --commit-lock-file
          else
            args=""
            for x in "$@"; do
              args="$args --update-input $x"
            done
            nix flake lock $args --commit-lock-file
          fi
        '';
        mkpw = ''
          pw=$(${pkgs.xkcdpass}/bin/xkcdpass)
          hashed=$(${pkgs.mkpasswd}/bin/mkpasswd -s -m sha512crypt <<< "$pw")
          cat << EOF
          users:
              root:
                  # $pw
                  password: $hashed
          EOF
        '';
        mkht = ''
          pw=$(${pkgs.pwgen}/bin/pwgen -s 32 1)
          echo "\`$1\` : \`$pw\`"
          ${pkgs.apacheHttpd}/bin/htpasswd -nbB "$1" "$pw" | head -1
        '';
      };
      scripts = pkgs.stdenv.mkDerivation {
        name = "scripts";
        unpackPhase = "true";
        installPhase = builtins.foldl' (acc: x: acc + "ln -s ${pkgs.writeShellScript "${x}.sh" scripts'.${x}} $out/bin/${x}; ") "mkdir -p $out/bin; " (builtins.attrNames scripts');
      };
    in {
      default = pkgs.mkShell {
        packages = [
          deploy-sh.packages.${system}.default
          (builtins.attrValues (import ./scripts pkgs))
          scripts
          self.formatter.${system}
        ];
      };
      ci = pkgs.mkShell {
        packages = [self.formatter.${system}];
      };
    });
    formatter = eachDefaultSystem (system: (import nixpkgs {inherit system;}).alejandra);
  };
}
