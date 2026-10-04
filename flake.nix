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
    llm-ms.url = "github:Bootstrap-Academy/llm-ms/1f73fc69903418854e7b91130586ee01306dfe07";

    skills-ms.url = "github:Bootstrap-Academy/skills-ms/d23843d4dbb822ee75c10d19265a62dcc0de5043";
    jobs-ms.url = "github:Bootstrap-Academy/jobs-ms/ea946c12f6f2caaa56e4b2e4edc73ce926ccfa2b";
    events-ms.url = "github:Bootstrap-Academy/events-ms/0e1b3772027ec151268afcfc461d3ca842a9d716";
    challenges-ms.url = "github:Bootstrap-Academy/challenges-ms/003f5e83a0c387e54c29f5a526f173c110060c3c";
    backend.url = "github:Bootstrap-Academy/backend/0aa5fa1785b702c22326bdc01c7b1ecc07c5e856";

    skills-ms-develop.url = "github:Bootstrap-Academy/skills-ms/d23843d4dbb822ee75c10d19265a62dcc0de5043";
    jobs-ms-develop.url = "github:Bootstrap-Academy/jobs-ms/ea946c12f6f2caaa56e4b2e4edc73ce926ccfa2b";
    events-ms-develop.url = "github:Bootstrap-Academy/events-ms/0e1b3772027ec151268afcfc461d3ca842a9d716";
    challenges-ms-develop.url = "github:Bootstrap-Academy/challenges-ms/003f5e83a0c387e54c29f5a526f173c110060c3c";
    backend-develop.url = "github:Bootstrap-Academy/backend/0aa5fa1785b702c22326bdc01c7b1ecc07c5e856";
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
        checks =
          let
            hosts = pkgs.linkFarm "checks-hosts" (
              lib.mapAttrs (_: v: v.config.system.build.toplevel) self.nixosConfigurations
            );
            devShells = pkgs.linkFarm "checks-devShells" self.devShells.${pkgs.stdenv.hostPlatform.system};
          in
          pkgs.linkFarmFromDrvs "checks" [
            self.packages.${pkgs.stdenv.hostPlatform.system}.private-lesson-header-tests
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
