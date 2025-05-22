{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-glitchtip.url = "github:NixOS/nixpkgs/pull/409813/merge";
    deploy-sh.url = "git+https://git.defelo.de/Defelo/deploy-sh";
    sops-nix.url = "github:Mic92/sops-nix";
    nfnix = {
      url = "git+https://git.defelo.de/Defelo/nfnix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko.url = "github:nix-community/disko";
    impermanence.url = "github:nix-community/impermanence";
    sandkasten.url = "github:Defelo/sandkasten";

    skills-ms.url = "github:Bootstrap-Academy/skills-ms/latest";
    jobs-ms.url = "github:Bootstrap-Academy/jobs-ms/latest";
    events-ms.url = "github:Bootstrap-Academy/events-ms/latest";
    challenges-ms.url = "github:Bootstrap-Academy/challenges-ms/latest";
    backend.url = "github:Bootstrap-Academy/backend/develop";

    skills-ms-develop.url = "github:Bootstrap-Academy/skills-ms/develop";
    jobs-ms-develop.url = "github:Bootstrap-Academy/jobs-ms/develop";
    events-ms-develop.url = "github:Bootstrap-Academy/events-ms/develop";
    challenges-ms-develop.url = "github:Bootstrap-Academy/challenges-ms/develop";
    backend-develop.url = "github:Bootstrap-Academy/backend/develop";
  };

  outputs =
    {
      self,
      nixpkgs,
      deploy-sh,
      sops-nix,
      disko,
      impermanence,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;

      eachDefaultSystem = lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ];

      extra-pkgs =
        system:
        lib.pipe inputs [
          (lib.filterAttrs (k: _: lib.hasPrefix "nixpkgs-" k))
          (lib.mapAttrs' (
            k: v: {
              name = lib.removePrefix "nix" k;
              value = import v { inherit system; };
            }
          ))
        ];

      getSystemFromHardwareConfiguration =
        hostName:
        let
          f = import ./hosts/${hostName}/hardware-configuration.nix;
          args = builtins.functionArgs f // {
            lib.mkDefault = lib.id;
          };
        in
        (f args).nixpkgs.hostPlatform;

      mkHost =
        name: system:
        lib.nixosSystem {
          inherit system;
          specialArgs = inputs // (extra-pkgs system) // { inherit inputs system name; };
          modules = [
            disko.nixosModules.default
            impermanence.nixosModule
            ./hosts/${name}
            ./hosts/${name}/hardware-configuration.nix
            ./modules
            {
              nixpkgs.overlays = [
                (final: prev: { inherit (inputs.nixpkgs-glitchtip.legacyPackages.${final.system}) glitchtip; })
              ];
            }
          ];
        };
    in
    {
      packages = eachDefaultSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          checks =
            let
              hosts = pkgs.linkFarm "checks-hosts" (
                lib.mapAttrs (_: v: v.config.system.build.toplevel) self.nixosConfigurations
              );
              devShells = pkgs.linkFarm "checks-devShells" self.devShells.${system};
            in
            pkgs.linkFarmFromDrvs "checks" [
              hosts
              devShells
            ];
        }
      );

      nixosConfigurations = lib.pipe ./hosts [
        builtins.readDir
        (lib.filterAttrs (_: type: type == "directory"))
        (builtins.mapAttrs (name: _: mkHost name (getSystemFromHardwareConfiguration name)))
      ];

      deploy-sh.hosts = self.nixosConfigurations;

      devShells = eachDefaultSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = import ./dev.nix (inputs // { inherit pkgs system; });
        }
      );

      formatter = eachDefaultSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.treefmt.withConfig {
          settings = [
            ./treefmt.nix
            { _module.args = { inherit pkgs; }; }
          ];
        }
      );
    };
}
