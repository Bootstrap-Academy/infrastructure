{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-glitchtip.url = "github:NixOS/nixpkgs";
    deploy-sh.url = "git+https://radicle.defelo.de/z392ZFR7AcScpaQqmTKUDkDj9FWMq.git";
    sops-nix.url = "github:Mic92/sops-nix";
    nfnix = {
      url = "git+https://radicle.defelo.de/z38ibAcVXcV86bVdfdMY9JXJcX5ZN.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko.url = "github:nix-community/disko";
    impermanence.url = "github:nix-community/impermanence";
    sandkasten.url = "git+https://radicle.defelo.de/zKBbWZxz73j7BZMbutM7TMMT4v5K.git";

    skills-ms.url = "github:Bootstrap-Academy/skills-ms/348c4b39407fcf9334aa5efd803bbcbe06a415f9";
    jobs-ms.url = "github:Bootstrap-Academy/jobs-ms/ea946c12f6f2caaa56e4b2e4edc73ce926ccfa2b";
    events-ms.url = "github:Bootstrap-Academy/events-ms/ff767ea8f76a253995b53fcfeb1217fe79f19da5";
    challenges-ms.url = "github:Bootstrap-Academy/challenges-ms/fcc9f52e568d322712a77552d404fab32fb1894c";
    backend.url = "github:Bootstrap-Academy/backend/fc0b82a5d1ce09eebd4cb77f8fe2220e943aeb90";

    skills-ms-develop.url = "github:Bootstrap-Academy/skills-ms/348c4b39407fcf9334aa5efd803bbcbe06a415f9";
    jobs-ms-develop.url = "github:Bootstrap-Academy/jobs-ms/ea946c12f6f2caaa56e4b2e4edc73ce926ccfa2b";
    events-ms-develop.url = "github:Bootstrap-Academy/events-ms/ff767ea8f76a253995b53fcfeb1217fe79f19da5";
    challenges-ms-develop.url = "github:Bootstrap-Academy/challenges-ms/fcc9f52e568d322712a77552d404fab32fb1894c";
    backend-develop.url = "github:Bootstrap-Academy/backend/fc0b82a5d1ce09eebd4cb77f8fe2220e943aeb90";
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

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      eachSystem = f: lib.genAttrs systems (s: f nixpkgs.legacyPackages.${s});

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
            { _module.args.env = import ./env.nix; }
          ];
        };
    in
    {
      packages = eachSystem (pkgs: {
        checks =
          let
            hosts = pkgs.linkFarm "checks-hosts" (
              lib.mapAttrs (_: v: v.config.system.build.toplevel) self.nixosConfigurations
            );
            devShells = pkgs.linkFarm "checks-devShells" self.devShells.${pkgs.stdenv.hostPlatform.system};
          in
          pkgs.linkFarmFromDrvs "checks" [
            hosts
            devShells
          ];
      });

      nixosConfigurations = lib.pipe ./hosts [
        builtins.readDir
        (lib.filterAttrs (_: type: type == "directory"))
        (builtins.mapAttrs (name: _: mkHost name (getSystemFromHardwareConfiguration name)))
      ];

      deploy-sh.hosts = self.nixosConfigurations;

      devShells = eachSystem (pkgs: {
        default = pkgs.callPackage ./dev.nix { inherit inputs; };
      });

      formatter = eachSystem (
        pkgs:
        pkgs.treefmt.withConfig {
          settings = lib.mkMerge [
            ./treefmt.nix
            { _module.args = { inherit pkgs; }; }
          ];
        }
      );
    };
}
