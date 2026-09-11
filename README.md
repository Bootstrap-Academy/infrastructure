# Bootstrap Academy Infrastructure
The [NixOS](https://nixos.org/) server configuration for hosting the backend of [Bootstrap Academy](https://bootstrap.academy/) on [Hetzner Cloud](https://www.hetzner.com/cloud).

If you would like to submit a bug report or feature request, or are looking for general information about the project or the publicly available instances, please refer to the [Bootstrap-Academy repository](https://github.com/Bootstrap-Academy/Bootstrap-Academy).

## Servers
| Name                                                                                     | Public IPv4      | Public IPv6               | Private IPv4 |
|------------------------------------------------------------------------------------------|------------------|---------------------------|--------------|
| [`prod`](https://console.hetzner.cloud/projects/2654383/servers/52842720/overview)       | `49.13.80.22`    | `2a01:4f8:c17:ad51::/64`  | `10.23.0.2`  |
| [`sandkasten`](https://console.hetzner.cloud/projects/2654383/servers/52832490/overview) | *None*           | *None*                    | `10.23.0.3`  |
| [`test`](https://console.hetzner.cloud/projects/2654383/servers/52823145/overview)       | `49.13.123.1`    | `2a01:4f8:c013:5e5f::/64` | `10.23.0.4`  |

## Administration

### Deployment
Follow the [coordinated release and recovery procedure](docs/COMPLIANCE-RELEASE.md) with an explicitly selected release manifest. Verify the exact source pins and keep application writers held until their migration and recovery prerequisites are met. Schema downgrades and arbitrary previous-generation activation are not safe recovery procedures.

On a system with [Nix](https://nixos.org/) installed, enter a dev shell using `nix develop` (or use [direnv](https://github.com/direnv/direnv)) and run the `deploy` command. For more information, run `deploy --help` or refer to the [readme of deploy-sh](https://radicle.defelo.de/nodes/radicle.defelo.de/rad:z392ZFR7AcScpaQqmTKUDkDj9FWMq).

### PostgreSQL
To connect to the database, run the postgres administration commands as the `postgres` user (e.g. `sudo -u postgres psql`).

### Redis
To connect to redis, run the `redis-cli` command.

## Retention

### Logs
`modules/logging.nix` is imported by `modules/default.nix` and therefore applies to every host.
It keeps journald entries for 30 days (`MaxRetentionSec=30day`, capped at `SystemMaxUse=1G`) and rotates the nginx access logs daily, keeping 30 rotations and dropping anything older than 30 days.
The nginx error log is written to stderr and ends up in the journal, so it is covered by the journald setting.

### Backups
`hosts/prod/restic.nix` defines the jobs that apply the retention policy to the three repositories the `prod` host is responsible for: `box-prod` and `box-test` on the Storage Box and `defelo-prod` on the REST target.
All three run daily at 04:20 and use the same policy:

```
--keep-hourly 48 --keep-daily 14 --keep-weekly 8 --keep-monthly 12
```

The backups themselves are taken by `modules/backup.nix`, which snapshots `/persistent/data` and pushes it to every target in `backup.targets` on the `backup.schedule` (hourly by default).

### Error reports
`hosts/prod/glitchtip.nix` pins `GLITCHTIP_RETENTION_DAYS = 90`, so GlitchTip deletes events after 90 days.

## Scheduled Cleanups
The microservices delete the data of accounts that no longer exist in the backend.
The deletion is propagated by the backend when an account is deleted; the timers below are the safety net for the calls that could not be delivered.
They are enabled on both `prod` and `test`:

| Service | Option | Time |
| --- | --- | --- |
| skills-ms | `academy.backend.skills.sweepDeletedUsers` | 03:10 |
| events-ms | `academy.backend.events.sweepDeletedUsers` | 03:25 |
| challenges-ms | `academy.backend.challenges.sweepDeletedUsers` | 03:40 |

The backend has its own timers (`services.academy.backend.tasks.<task>.schedule`), which its NixOS module defaults to hourly for `prune-database` and daily for `refresh-premium`.

## Sandbox Exposure
`sandkasten.bootstrap.academy` (`hosts/prod/nginx.nix`) proxies the code execution service, which is only meant to be called by challenges-ms over the internal network.
The vhost is therefore restricted with `allow = env.wg.admins ++ [ env.net.hosts ]`; every other client gets a `403`, including on `/docs`.
Requests that do not come from the WireGuard network are additionally rate limited to 20 requests per minute with a burst of 5 (`429` beyond that), and `/metrics` returns `403` for everyone.
