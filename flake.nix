{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    deploy-sh.url = "github:Defelo/deploy-sh";
    sops-nix.url = "github:Mic92/sops-nix";
    nfnix.url = "github:Defelo/nfnix";
    disko.url = "github:nix-community/disko";
    impermanence.url = "github:nix-community/impermanence";
    sandkasten.url = "github:Defelo/sandkasten";

    auth-ms.url = "github:Bootstrap-Academy/auth-ms/latest";
    skills-ms.url = "github:Bootstrap-Academy/skills-ms/latest";
    shop-ms.url = "github:Bootstrap-Academy/shop-ms/latest";
    jobs-ms.url = "github:Bootstrap-Academy/jobs-ms/latest";
    events-ms.url = "github:Bootstrap-Academy/events-ms/latest";
    challenges-ms.url = "github:Bootstrap-Academy/challenges-ms/latest";

    auth-ms-develop.url = "github:Bootstrap-Academy/auth-ms/develop";
    skills-ms-develop.url = "github:Bootstrap-Academy/skills-ms/develop";
    shop-ms-develop.url = "github:Bootstrap-Academy/shop-ms/develop";
    jobs-ms-develop.url = "github:Bootstrap-Academy/jobs-ms/develop";
    events-ms-develop.url = "github:Bootstrap-Academy/events-ms/develop";
    challenges-ms-develop.url = "github:Bootstrap-Academy/challenges-ms/develop";
  };

  outputs = {
    self,
    nixpkgs,
    deploy-sh,
    sops-nix,
    disko,
    impermanence,
    ...
  } @ inputs: let
    inherit (nixpkgs) lib;

    defaultSystems = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    eachDefaultSystem = lib.genAttrs defaultSystems;

    env = import ./env.nix;

    docker-images = fromTOML (builtins.readFile ./docker-images.toml);

    extra-pkgs = system:
      lib.pipe inputs [
        (lib.filterAttrs (k: _: lib.hasPrefix "nixpkgs-" k))
        (lib.mapAttrs' (k: v: {
          name = lib.removePrefix "nix" k;
          value = import v {inherit system;};
        }))
      ];

    getSystemFromHardwareConfiguration = hostName: let
      f = import ./hosts/${hostName}/hardware-configuration.nix;
      args = builtins.functionArgs f // {lib.mkDefault = lib.id;};
    in
      (f args).nixpkgs.hostPlatform;

    mkHost = name: system:
      lib.nixosSystem {
        inherit system;
        specialArgs = inputs // (extra-pkgs system) // {inherit inputs docker-images system env name;};
        modules = [
          disko.nixosModules.default
          impermanence.nixosModule
          ./hosts/${name}
          ./hosts/${name}/hardware-configuration.nix
          ./new-modules
        ];
      };
  in {
    nixosConfigurations =
      builtins.mapAttrs (name: server:
        lib.nixosSystem {
          inherit (server) system;
          specialArgs =
            inputs
            // (lib.mapAttrs' (name: value: {
              name = lib.removePrefix "nix" name;
              value = import value {inherit (server) system;};
            }) (lib.filterAttrs (name: _: lib.hasPrefix "nixpkgs-" name) inputs))
            // {
              inherit env server;
              docker-images = fromTOML (builtins.readFile ./docker-images.toml);
            };
          modules = [
            deploy-sh.nixosModules.default
            sops-nix.nixosModules.default
            ./hosts/${name}
            ./hosts/${name}/hardware-configuration.nix
            ./modules
            {
              networking.hostName = name;
              deploy-sh.targetHost = "root@${server.net.private.ip4}";
              sops.defaultSopsFile = ./hosts/${name}/secrets.yml;
            }
          ];
        })
      env.servers
      // lib.genAttrs ["test"] (name: mkHost name (getSystemFromHardwareConfiguration name));

    deploy-sh.hosts = self.nixosConfigurations;

    devShells = eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      default = pkgs.mkShell {
        packages = with pkgs;
          [sops ssh-to-age nixos-anywhere]
          ++ [
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
