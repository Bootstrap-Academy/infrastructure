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
On a system with [Nix](https://nixos.org/) installed, enter a dev shell using `nix develop` (or use [direnv](https://github.com/direnv/direnv)) and run the `deploy` command. For more information, run `deploy --help` or refer to the [readme of deploy-sh](https://github.com/Defelo/deploy-sh).

### PostgreSQL
To connect to the database, run the postgres administration commands as the `postgres` user (e.g. `sudo -u postgres psql`).

### Redis
To connect to redis, run the `redis-cli` command.
