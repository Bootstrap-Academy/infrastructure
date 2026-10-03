# Prepared activation; deliberately not imported by hosts/prod/default.nix.
{ ... }: {
  monitoring.alerting = {
    enable = true;
    probes = {
      api = {
        url = "https://api.bootstrap.academy/health";
        module = "database";
      };
      skills.url = "https://api.bootstrap.academy/skills/skilltree";
      challenges.url = "https://api.bootstrap.academy/challenges/openapi.json";
      frontend.url = "https://bootstrap.academy/";
    };
  };
  environment.persistence."/persistent/data".directories = [
    "/var/lib/prometheus2"
    "/var/lib/alertmanager"
    "/var/lib/academy-backup-metrics"
  ];
}
