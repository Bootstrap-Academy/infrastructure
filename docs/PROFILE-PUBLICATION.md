# Profile publication: ingress and recovery

`academy.backend.profilePublication.enable` defaults to false. Enabling this preparation changes only the selected host. It does not activate privacy, publish profiles, migrate visibility, send mail or change learning data. Production and Test pins are separate. Keep selected application reviews and release evidence in restricted operations storage.

The enabled module has three explicit modes:

| Mode | Service switches and ingress |
| --- | --- |
| `prepare` | Capable services have publication disabled. Legacy rankings remain available only while the database policy has never been activated and no persistent fence exists. |
| `closed` | Publication disabled; rankings and profile projections return 503. Old or mixed readers can run only behind this fence. Use this mode before activation. |
| `shared` | Backend, Skills and Challenges switches enabled together. All selected source contracts and actual service package bindings must support `academy-verified-v1`. The ingress startup guard also requires the matching activated database policy. Readers check fresh authority on every ranking response. |

Settings are only added to packages that support their contract. Unknown/incomplete capabilities cannot open shared mode. The source checks identify compatible contracts; independent reviews and the combined application acceptance remain required. Capabilities alone do not establish application correctness.

Person endpoints (`/auth/users`, `/skills/xp`, rankings, future `/profiles`) have `Cache-Control: private, no-store` and authentication/origin variance on successes and errors. Proxy caches and conditional reuse are disabled. An upstream 304 becomes an unavailable response. Direct `_internal` requests, including the path without its final slash, return 403 before public proxy locations. Service authentication still protects internal calls over loopback. Existing catalog, lesson module and learning ingress stays independent.

## Activation

Before activating the durable privacy policy, deploy `closed` with the coordinated Test/production release procedure. The oneshot guard checks only the backend singleton policy using a read-only PostgreSQL transaction. Verify the root-owned marker `/persistent/data/academy-profile-publication/private-policy` exists, and all six rankings and profile projections are closed. The directory allows Nginx to check existence; the marker contents are root-only. Closing never deletes the marker.

Then carry out the separately reviewed V8 visibility activation using the current backend tool and verify all existing accounts are private. This module performs no visibility writes. Check compatible Readers/clients, legal text, warm application cache withdrawal, private learning paths and zero financial/mail side effects before selecting `shared`. Explicitly run `systemctl start academy-profile-publication-guard` and verify its success before a reload that opens shared ingress; an Nginx reload does not itself rerun a oneshot dependency. If the policy check is uncertain, keep `closed`.

Read the actual CDN configuration before activation. `no-store` stops new storage; it does not purge old HTTP objects. Inspect personalized route responses with and without conditional/origin headers. Record actual purge results if a purge is required. Do not claim that earlier copies, screenshots or rendered pages disappear.

## Recovery

Never disable this module, remove its persistent fence, or select a pre-fence infrastructure generation after activation. Preserve the marker together with current databases and post-snapshot withdrawals/deletions. If restore evidence is incomplete, select `closed`. An activated database automatically recreates a missing marker at ingress startup; unavailable or unrecognized policy also fences and refuses startup. An old snapshot cannot establish permission to publish.

`academy.v2Recovery = true` overrides publication to closed even if the normal configuration says shared. It retains the current packages, native migrations, schema and policy generation; existing recovery admission holds remain in force. Reopening requires the reviewed forward generation. Downgrading the privacy schema or merely turning Readers off cannot restore legacy rankings. Existing learning runtime recovery rules and writer holds continue to apply.

Validate configuration modes and package mismatch with `tests/profile-publication-config.nix`. Build `.#profile-publication-tests` for a disposable PostgreSQL/Nginx VM covering HTTP errors, conditional reuse, internal ingress, persistent fences, inactive/unknown policy and restart/recovery behavior. The VM uses synthetic fixtures; it does not prove live application or CDN behavior.
