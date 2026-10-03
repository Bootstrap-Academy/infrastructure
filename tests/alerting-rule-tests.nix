{ pkgs, lib }:
let
  rules = import ../modules/alerting-rules.nix {
    holdFor = "2m";
    backupMaxAge = 10800;
    certificateDays = 14;
    link = "https://runbook.example.test/";
  };
  json = pkgs.formats.json { };
  series = name: values: {
    series = name;
    inherit values;
  };
  expected = alertname: labels: {
    exp_labels = labels;
    exp_annotations = {
      summary = alertname;
      link = "https://runbook.example.test/";
    };
  };
  test = alertname: input_series: labels: {
    interval = "1m";
    inherit input_series;
    alert_rule_test = [
      {
        eval_time = "1m";
        inherit alertname;
        exp_alerts = [ ];
      }
      {
        eval_time = "2m";
        inherit alertname;
        exp_alerts = [ (expected alertname labels) ];
      }
    ];
  };
  input = {
    rule_files = [ (json.generate "rules.json" rules) ];
    evaluation_interval = "1m";
    tests = [
      (test "AcademyServiceDown"
        [ (series ''probe_success{job="academy-http",host="test",service="api"}'' "0x5") ]
        {
          job = "academy-http";
          host = "test";
          service = "api";
        }
      )
      (test "AcademyMonitoringDown" [ (series ''up{job="academy-blackbox",host="test"}'' "0x5") ] {
        job = "academy-blackbox";
        host = "test";
        service = "monitoring";
      })
      (test "AcademyBackupFailed"
        [
          (series ''academy_backup_last_success_seconds{host="test",service="backup",unit="box"}'' "100x5")
          (series ''academy_backup_last_failure_seconds{host="test",service="backup",unit="box"}'' "101x5")
        ]
        {
          host = "test";
          service = "backup";
          unit = "box";
        }
      )
      (test "AcademyBackupOverdue"
        [
          (series ''academy_backup_last_success_seconds{host="test",service="backup",unit="box"}'' "-11000x5")
          (series ''academy_backup_observed_since_seconds{host="test",service="backup",unit="box"}'' "-11000x5")
        ]
        {
          host = "test";
          service = "backup";
          unit = "box";
        }
      )
      (test "AcademyDiskAlmostFull"
        [
          (series ''node_filesystem_avail_bytes{host="test",mountpoint="/persistent/data"}'' "1000000000x5")
          (series ''node_filesystem_size_bytes{host="test",mountpoint="/persistent/data"}'' "20000000000x5")
        ]
        {
          host = "test";
          service = "disk";
        }
      )
      (test "AcademyCertificateExpiring"
        [
          (series ''probe_ssl_earliest_cert_expiry{job="academy-http",host="test",service="frontend"}'' "1123200x5")
        ]
        {
          job = "academy-http";
          host = "test";
          service = "frontend";
        }
      )
      (test "AcademyBackupMetricsMissing" [ (series ''up{job="academy-node",host="test"}'' "1x5") ] {
        job = "academy-node";
        host = "test";
        service = "backup";
      })
      {
        interval = "1m";
        input_series = [
          (series ''probe_success{job="academy-http",host="test",service="api"}'' "1x5")
          (series ''up{job="academy-node",host="test"}'' "1x5")
          (series ''up{job="academy-blackbox",host="test"}'' "1x5")
          (series ''academy_backup_observed_since_seconds{host="test",service="backup",unit="box"}'' "0x5")
          (series ''academy_backup_last_success_seconds{host="test",service="backup",unit="box"}'' "100x5")
          (series ''academy_backup_last_failure_seconds{host="test",service="backup",unit="box"}'' "99x5")
          (series ''node_filesystem_avail_bytes{host="test",mountpoint="/persistent/data"}'' "15000000000x5")
          (series ''node_filesystem_size_bytes{host="test",mountpoint="/persistent/data"}'' "20000000000x5")
          (series ''probe_ssl_earliest_cert_expiry{job="academy-http",host="test",service="frontend"}'' "2592000x5")
        ];
        alert_rule_test = map (rule: {
          eval_time = "4m";
          alertname = rule.alert;
          exp_alerts = [ ];
        }) (builtins.head rules.groups).rules;
      }
    ];
  };
in
pkgs.runCommand "academy-alerting-rules-tested" { nativeBuildInputs = [ pkgs.prometheus.cli ]; } ''
  promtool check rules ${json.generate "rules.json" rules}
  promtool test rules ${json.generate "rule-tests.json" input}
  touch $out
''
