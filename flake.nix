{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-glitchtip.url = "github:NixOS/nixpkgs";
    deploy-sh.url = "github:Bootstrap-Academy/deploy-sh/5c9c65ffbb689c2f193edc628c2e6d95ca386d4f";
    sops-nix.url = "github:Mic92/sops-nix";
    nfnix = {
      url = "github:Bootstrap-Academy/nfnix/cc52fbfc6e7510a628e7cf34fc2f1e3809ae13f5";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko.url = "github:nix-community/disko";
    impermanence.url = "github:nix-community/impermanence";
    sandkasten = {
      url = "github:Bootstrap-Academy/sandkasten/97de259259d33b6fb7bbbf0d6db94b037d189b53";
      inputs.radicle-update.url = "github:Bootstrap-Academy/radicle-update/52d7120369f13918076855823fd042f540e8f97b";
    };
    llm-ms.url = "github:Bootstrap-Academy/llm-ms/1f73fc69903418854e7b91130586ee01306dfe07";

    skills-ms.url = "github:Bootstrap-Academy/skills-ms/c9394e69d6d15f7dcf85f476b2982d28500fb30b";
    jobs-ms.url = "github:Bootstrap-Academy/jobs-ms/9901fa3a54a6f340104e15bb527e8ac988cbb904";
    events-ms.url = "github:Bootstrap-Academy/events-ms/e04605e85caaf5c5c1f3566f647c19d01f008c9b";
    challenges-ms.url = "github:Bootstrap-Academy/challenges-ms/6ef631ca7b94d5077140f8573f1671825573aefb";
    backend.url = "github:Bootstrap-Academy/backend/ebe279836467852b3225af2edae6c3e37fbb2468";

    skills-ms-develop.url = "github:Bootstrap-Academy/skills-ms/c9394e69d6d15f7dcf85f476b2982d28500fb30b";
    jobs-ms-develop.url = "github:Bootstrap-Academy/jobs-ms/9901fa3a54a6f340104e15bb527e8ac988cbb904";
    events-ms-develop.url = "github:Bootstrap-Academy/events-ms/e04605e85caaf5c5c1f3566f647c19d01f008c9b";
    challenges-ms-develop.url = "github:Bootstrap-Academy/challenges-ms/6ef631ca7b94d5077140f8573f1671825573aefb";
    backend-develop.url = "github:Bootstrap-Academy/backend/ebe279836467852b3225af2edae6c3e37fbb2468";
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
        profile-publication-tests = pkgs.callPackage ./tests/profile-publication.nix { inherit self; };
        profile-publication-config-tests = pkgs.callPackage ./tests/profile-publication-config.nix {
          inherit self;
        };
        grafana-key-activation =
          (self.nixosConfigurations.prod.extendModules {
            modules = [
              ./hosts/prod/grafana-runtime-key.nix
              ./hosts/prod/alerting.nix
            ];
          }).config.system.build.toplevel;
        grafana-key-migration = pkgs.callPackage ./scripts/grafana-key-migration.nix { };
        grafana-key-migration-tests = pkgs.callPackage ./tests/grafana-key-migration.nix { inherit self; };
        alerting-rule-tests = import ./tests/alerting-rule-tests.nix { inherit pkgs lib; };
        alerting-tests = pkgs.callPackage ./tests/alerting.nix { inherit self; };
        private-lesson-header-tests = import ./tests/private-lesson-headers.nix { inherit self; };
        lesson-package-header-tests = import ./tests/lesson-package-headers.nix { inherit self; };
        checks =
          let
            hosts = pkgs.linkFarm "checks-hosts" (
              lib.mapAttrs (_: v: v.config.system.build.toplevel) self.nixosConfigurations
            );
            devShells = pkgs.linkFarm "checks-devShells" self.devShells.${pkgs.stdenv.hostPlatform.system};
          in
          pkgs.linkFarmFromDrvs "checks" [
            self.packages.${pkgs.stdenv.hostPlatform.system}.private-lesson-header-tests
            self.packages.${pkgs.stdenv.hostPlatform.system}.lesson-package-header-tests
            hosts
            devShells
            self.checks.${pkgs.stdenv.hostPlatform.system}.sandbox-hardening
            self.packages.${pkgs.stdenv.hostPlatform.system}.grafana-key-migration-tests
            self.packages.${pkgs.stdenv.hostPlatform.system}.profile-publication-tests
            self.packages.${pkgs.stdenv.hostPlatform.system}.profile-publication-config-tests
          ];
      });

      checks = eachSystem (pkgs: {
        sandbox-hardening = import ./tests/sandbox-hardening.nix {
          inherit pkgs;
          inherit (inputs) sandkasten;
        };
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
