{ writeShellApplication, python3 }:
writeShellApplication {
  name = "grafana-key-migration";
  runtimeInputs = [ (python3.withPackages (ps: [ ps.cryptography ])) ];
  text = ''
    exec python3 ${./grafana-key-migration.py} "$@"
  '';
}
