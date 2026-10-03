# Operational alerts

`monitoring.alerting.enable` starts native Prometheus, Blackbox Exporter and Alertmanager on
loopback only (9090, 9115, 9093). It uses the existing node exporter on 9000. It is enabled on
Test; Prod stays unchanged until `hosts/prod/alerting.nix` is explicitly imported.

The provisioned checks cover API database/cache health, public skilltree access, Challenges
process reachability and the frontend. A health response with `database:false` fails even if
its HTTP status is 200. The Challenges OpenAPI probe proves HTTP process reachability; the
monolith database probe covers their shared PostgreSQL separately. The database startup
failure from the October 2 incident would trigger `AcademyServiceDown` after two minutes of
bad probes, plus up to 30 seconds for evaluation and 30 seconds for notification grouping.

Other rules cover failed backups, three hours without a confirmed success, missing backup
metrics, less than 10% or 2 GiB of free persistent storage, certificates expiring within 14 days
and failed monitoring exporters. Node filesystem free space is not a complete Btrfs metadata
health check. All conditions must persist for two minutes. Alertmanager groups by host and
service, updates groups at most every five minutes and repeats unresolved groups every twelve
hours. Resolutions are sent too. Backups record their actual `SERVICE_RESULT` in `ExecStopPost`;
failure does not erase the previous success. Observation start is separate from success, with
a three-hour initial grace period. Metrics persist in `/var/lib/academy-backup-metrics`.
Recorders and the node exporter require that directory's mount before starting; the exporter
also waits for metric initialization. This preserves every unit's state during first activation.

## Webhook secret

The URL is not supplied yet. With the file absent, Alertmanager starts with an empty native
receiver and logs `n8n webhook URL missing; alert delivery disabled`. No request or email is sent.
A small renderer chooses this no-op or the native webhook receiver; it does not send messages.

When the owner supplies the URL, add `academy-alerting/n8n-webhook-url` to the host's encrypted
`secrets.yml` using the established SOPS editor and project age key. Preserve other entries.
Then set `monitoring.alerting.webhookSecret.enable = true` and deploy that host through the
normal procedure. SOPS creates `/run/secrets/academy-alerting/n8n-webhook-url`, owned by
`academy-alerting`, mode 0400, and restarts Alertmanager on changes. The renderer keeps the URL
out of the Nix store and service environment; the runtime config is in the service's private
`/tmp` with mode 0600. Do not capture its contents or raw notification-error logs as evidence.
Removing an unprovisioned file and restarting Alertmanager returns to the no-op receiver.

The native [Alertmanager webhook JSON](https://prometheus.io/docs/alerting/latest/configuration/#webhook_config)
contains an `alerts` array (at most ten per message). Each entry supplies:

| Needed field | Native payload field |
| --- | --- |
| Host | `labels.host` |
| Service | `labels.service` (backup entries also have `labels.unit`) |
| State | `status`, either `firing` or `resolved` |
| Since | `startsAt` |
| Link | `annotations.link` |

No request text, user identifiers or credentials belong in alert labels. n8n can map these five
fields directly and retain the native `fingerprint` for deduplication. Contact points, routing,
grouping, retry and resolution use native Alertmanager configuration.

## Production activation

This is a prepared release step requiring the owner's production go:

1. Start from fresh `infrastructure/main` and read the actual live deployment state. Import
   `./alerting.nix` in `hosts/prod/default.nix`. This enables the local monitoring services, backup
   result hooks, persistent state and a provisioned Prometheus datasource in existing Grafana.
   It does not enable `llm-ms` on Prod or supply any provider credentials.
2. Provision the owner's webhook via SOPS as above. Enable `webhookSecret` only after the
   encrypted entry exists. An activation without the URL intentionally evaluates alerts without
   delivering them; it is not completed notification coverage.
3. Run format, Python checks, `alerting-rule-tests`, `alerting-tests`, the normal host checks,
   system build and `deploy --eval --diff prod`. Review service/backup restarts against active
   jobs. Take the current budget reading required by the release rules.
4. Deploy with the pinned standard tool, then run `deploy --check` and `deploy --eval --diff`
   for the actual host scope. Confirm all probes are successful and all native services healthy.
   Trigger a labeled synthetic test alert, confirm exactly one n8n firing and one resolution,
   then read the normal non-test rules again. Keep the URL out of logs and reports.
5. Publish the reviewed configuration through the signed, protected main PR procedure and
   record the exact system path, source pins, receiver verification and cleanup privately.

Local monitoring continues during an application or database outage. If its entire host fails,
that host cannot deliver its own alarms; provision an external check from another host for
complete host failures. Grafana and GlitchTip still run on Prod and therefore share that limit.
Manual GlitchTip/Grafana project settings are not inferred from infrastructure configuration.

For a read-only evaluation of the prepared activation without changing the default host:

```nix
let
  flake = builtins.getFlake "git+file:///path/to/infrastructure?rev=<reviewed-commit>";
  enabled = flake.nixosConfigurations.prod.extendModules {
    modules = [ /path/to/infrastructure/hosts/prod/alerting.nix ];
  };
in enabled.config.system.build.toplevel.drvPath
```

Recovery removes that explicit import and the matching webhook-secret declaration through a
reviewed compatible system release. Backup snapshots, database schemas and provider access
remain independent. Preserve backup metrics and monitoring history unless disposal is separately
authorized.
