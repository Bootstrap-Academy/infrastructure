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
    env = import ./env.nix;
  in {
    nixosConfigurations = builtins.mapAttrs (name: server:
      nixpkgs.lib.nixosSystem {
        inherit (server) system;
        specialArgs = inputs // {inherit env;};
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
