{ lib, pkgs, ... }:

{
  tree-root-file = "flake.nix";
  on-unmatched = "error";

  excludes = [
    "**/__pycache__/**"
    ".envrc"
    "*.md"
    "*.patch"
    ".gitignore"
    "flake.lock"
    "hosts/*/hardware-configuration.nix"
    "hosts/*/secrets.yml"
    "scripts/grafana-key-migration.py"
    "tests/grafana-key-fixture.py"
    "hosts/prod/grafana-runtime-key.yml"
    "scripts/release-preflight.py"
    "scripts/alertmanager-config.py"
    "scripts/backup-metrics.py"
    "scripts/test-alerting.py"
    "scripts/test-backup-preparation.py"
    "scripts/test-postgres-startup-crash.py"
  ];

  formatter.nixfmt = {
    command = lib.getExe pkgs.nixfmt;
    includes = [ "*.nix" ];
    options = [ "--strict" ];
  };

  formatter.prettier = {
    command = lib.getExe pkgs.prettier;
    includes = [
      "*.js"
      "*.mjs"
      "*.json"
      "*.yaml"
      "*.yml"
    ];
    options = [ "--write" ];
  };
}
