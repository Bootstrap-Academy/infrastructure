{
  holdFor,
  backupMaxAge,
  certificateDays,
  link,
  # Probes labelled certificate="shortlived" (about 160 hours) get their own threshold in hours.
  shortLivedCertificates ? false,
  shortLivedCertificateHours ? 48,
}:
let
  rule = alert: expr: service: {
    inherit alert expr;
    for = holdFor;
    labels = { inherit service; };
    annotations = {
      summary = alert;
      inherit link;
    };
  };
in
{
  groups = [
    {
      name = "academy-operations";
      rules = [
        (rule "AcademyServiceDown" ''probe_success{job="academy-http"} == 0'' "{{ $labels.service }}")
        (rule "AcademyMonitoringDown" ''up{job=~"academy-node|academy-http|academy-blackbox"} == 0''
          "monitoring"
        )
        (rule "AcademyBackupFailed"
          "academy_backup_last_failure_seconds > academy_backup_last_success_seconds"
          "backup"
        )
        (rule "AcademyBackupOverdue"
          "(time() - academy_backup_last_success_seconds > ${toString backupMaxAge}) and (time() - academy_backup_observed_since_seconds > ${toString backupMaxAge})"
          "backup"
        )
        (rule "AcademyDiskAlmostFull"
          ''min by (host) (node_filesystem_avail_bytes{mountpoint="/persistent/data"} / node_filesystem_size_bytes{mountpoint="/persistent/data"}) < 0.1 or min by (host) (node_filesystem_avail_bytes{mountpoint="/persistent/data"}) < 2147483648''
          "disk"
        )
        (rule "AcademyCertificateExpiring" ''probe_ssl_earliest_cert_expiry{job="academy-http"${
          if shortLivedCertificates then '',certificate!="shortlived"'' else ""
        }} - time() < ${toString (certificateDays * 86400)}'' "{{ $labels.service }}")
        (rule "AcademyBackupMetricsMissing"
          ''up{job="academy-node"} == 1 unless on(host) academy_backup_observed_since_seconds''
          "backup"
        )
      ]
      ++ (
        if shortLivedCertificates then
          [
            (rule "AcademyShortLivedCertificateExpiring"
              ''probe_ssl_earliest_cert_expiry{job="academy-http",certificate="shortlived"} - time() < ${
                toString (shortLivedCertificateHours * 3600)
              }''
              "{{ $labels.service }}"
            )
          ]
        else
          [ ]
      );
    }
  ];
}
