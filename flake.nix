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
    backend-develop.url = "github:Bootstrap-Academy/backend/develop";
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
        specialArgs = inputs // (extra-pkgs system) // {inherit inputs system name;};
        modules = [
          disko.nixosModules.default
          impermanence.nixosModule
          ./hosts/${name}
          ./hosts/${name}/hardware-configuration.nix
          ./modules
        ];
      };
  in {
    nixosConfigurations = lib.pipe ./hosts [
      builtins.readDir
      (lib.filterAttrs (_: type: type == "directory"))
      (builtins.mapAttrs (name: _: mkHost name (getSystemFromHardwareConfiguration name)))
    ];

    deploy-sh.hosts = self.nixosConfigurations;

    devShells = eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      default = import ./dev.nix (inputs // {inherit pkgs system;});
      ci = pkgs.mkShell {
        packages = [self.formatter.${system}];
      };
    });

    formatter = eachDefaultSystem (system: (import nixpkgs {inherit system;}).alejandra);
  };

  nixConfig = {
    extra-substituters = "https://academy-backend.cachix.org";
    extra-trusted-public-keys = "academy-backend.cachix.org-1:MxmjN6hjaiGdi42M6evdALWj5hHOyUAQTEgKvm+J0Ow=";
  };
}
