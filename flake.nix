{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    deploy-sh.url = "github:Defelo/deploy-sh";
    sops-nix.url = "github:Mic92/sops-nix";
    nfnix.url = "github:Defelo/nfnix";
    sandkasten.url = "github:Defelo/sandkasten";

    auth-ms-develop.url = "github:Bootstrap-Academy/auth-ms/develop";
    skills-ms-develop.url = "github:Bootstrap-Academy/skills-ms/develop";
    shop-ms-develop.url = "github:Bootstrap-Academy/shop-ms/develop";
    jobs-ms-develop.url = "github:Bootstrap-Academy/jobs-ms/develop";
    events-ms-develop.url = "github:Bootstrap-Academy/events-ms/develop";
    challenges-ms.url = "github:Bootstrap-Academy/challenges-ms/latest";
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
    in {
      default = pkgs.mkShell {
        packages = [
          deploy-sh.packages.${system}.default
          (builtins.attrValues (import ./scripts pkgs))
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
