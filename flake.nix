{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    deploy-sh.url = "github:Defelo/deploy-sh";
    sops-nix.url = "github:Mic92/sops-nix";
    nfnix.url = "github:Defelo/nfnix";
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
  in {
    nixosConfigurations = {
      academy = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = inputs;
        modules = [
          deploy-sh.nixosModules.default
          sops-nix.nixosModules.default
          ./hosts/academy
          ./modules
        ];
      };
      sandkasten = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = inputs;
        modules = [
          deploy-sh.nixosModules.default
          sops-nix.nixosModules.default
          ./hosts/sandkasten
          ./modules
        ];
      };
    };
    devShells = eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      default = pkgs.mkShell {
        packages = [
          (deploy-sh.lib.mkDeploy {
            inherit pkgs;
            hosts = self.nixosConfigurations;
          })
        ];
      };
    });
  };
}
