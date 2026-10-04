{ pkgs, sandkasten }:
let
  compile = pkgs.writeShellScript "artifact-probe-compile" ''
    set -euo pipefail
    exec ${pkgs.python3}/bin/python /box/"$1"
  '';
  run = pkgs.writeShellScript "artifact-probe-run" ''
    set -euo pipefail
    echo OK
  '';
  probe = (pkgs.formats.json { }).generate "artifact-probe.json" {
    id = "artifact-probe";
    name = "VM-only bounded artifact writer";
    version = "1";
    sandkasten_version = "0.2.2";
    meta = { };
    default_main_file_name = "code.py";
    compile_script = toString compile;
    run_script = toString run;
    run_extra_tmpfs = [ ];
    closure = "${
      pkgs.closureInfo {
        rootPaths = [
          compile
          run
        ];
      }
    }/store-paths";
    example = null;
    test = {
      main_file = {
        name = "code.py";
        content = "print('OK')";
      };
      files = [ ];
      expected = "OK";
    };
  };
in
pkgs.testers.runNixOSTest {
  name = "academy-sandbox-hardening";
  node.specialArgs = { inherit sandkasten; };
  nodes.machine = { lib, ... }: {
    imports = [
      ../modules/sandbox-hardening.nix
      ../hosts/sandkasten/sandkasten.nix
    ];
    academy.sandboxHardening = {
      enable = true;
      # Exercise ENOSPC safely; production/test defaults are evaluated separately.
      cacheMiB = 32;
      cacheInodes = 256;
    };
    services.sandkasten = {
      environments = lib.mkForce (
        p:
        p.selected (
          envs: with envs; [
            python
            java
            kotlin
          ]
        )
      );
      settings = {
        environments_path = lib.mkAfter [
          (pkgs.linkFarm "artifact-probe" { "artifact-probe.json" = probe; })
        ];
        program_ttl = lib.mkForce 2;
        prune_programs_interval = lib.mkForce 1;
        # Emulated/contended CI guests need wall-clock slack. Host budgets remain
        # the existing 30-second compilation and 5-second execution limits.
        compile_limits.time = lib.mkForce 120;
        run_limits.time = lib.mkForce 30;
      };
    };
    environment.systemPackages = [
      pkgs.python3
      pkgs.procps
    ];
    environment.etc."sandbox-hardening-probe.py".source = ./sandbox-hardening.py;
    virtualisation.memorySize = 4096;
  };
  testScript = ''
    machine.start()
    machine.wait_for_unit("sandkasten.service")
    machine.wait_for_open_port(8000)
    machine.wait_for_unit("multi-user.target")
    print(machine.succeed("python /etc/sandbox-hardening-probe.py"))
    machine.succeed("systemctl is-active sandkasten.service")
  '';
}
