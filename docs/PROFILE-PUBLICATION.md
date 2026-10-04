# Profile publication: ingress and recovery

`academy.backend.profilePublication.enable` defaults to false. Enabling this preparation changes only the selected host. It does not activate privacy, publish profiles, migrate visibility, send mail or change learning data. Production and Test pins are separate. Keep selected application reviews and release evidence in restricted operations storage.

The enabled module has three explicit modes:

| Mode | Service switches and ingress |
| --- | --- |
| `prepare` | Capable services have publication disabled. Legacy rankings remain available only while the guard has confirmed that the database policy was never activated and no persistent fence exists. |
| `closed` | Publication disabled; rankings and profile projections return 503. Old or mixed readers can run only behind this fence. Use this mode before activation. |
| `shared` | Backend, Skills and Challenges switches enabled together. All selected source contracts and actual service package bindings must support `academy-verified-v1`. The guard also requires the matching activated database policy. Readers check fresh authority on every ranking response. |

Settings are only added to packages that support their contract. Unknown/incomplete capabilities cannot open shared mode. The source checks identify compatible contracts; independent reviews and the combined application acceptance remain required. Capabilities alone do not establish application correctness.

Person endpoints (`/auth/users`, `/auth/session`, `/auth/sessions`, `/auth/oauth/links`, `/auth/moderation`, `/shop/coins`, `/shop/hearts`, `/shop/premium`, `/admin/audit-log`, `/skills/xp`, rankings, future `/profiles`) have `Cache-Control: private, no-store` and authentication/origin variance on successes and errors. Proxy caches and conditional reuse are disabled. An upstream 304 becomes an unavailable response. Direct `_internal` requests, including the path without its final slash, return 403 before public proxy locations. Service authentication still protects internal calls over loopback. Existing catalog, lesson module and learning ingress stays independent. Challenge listings filtered by `creator` are not covered here; author references belong to the services (PRIV-01 V4).

## Guard and release flag

The oneshot guard `academy-profile-publication-guard` reads only the backend singleton policy, in a read-only PostgreSQL transaction on the database named by `services.academy.backend.settings.database.url`. Nginx starts independently of its result. Rankings and profile projections open only while `/run/academy-profile-publication/released-<mode>` exists, and only a successful guard run of that mode creates it: `prepare` when the policy was never activated and no marker exists, `shared` when the policy is active. Every failed, killed or timed-out run removes the flags; `closed` and recovery never create one. A reboot starts closed.

Nginx wants the guard and starts after it, so a restart rechecks first; a failed guard leaves Nginx and every other virtual host running. The guard never starts PostgreSQL. A timer reruns it 30 seconds after activation and one minute after each run, so the surfaces reopen on their own once the database is back, and a changed mode takes effect after the next run. An Nginx reload or a configuration switch does not run the guard by itself.

Before activation, `prepare` and recovery write the persistent marker only when the policy is active. A database outage therefore closes legacy rankings just until the next successful run.

## Activation

Before activating the durable privacy policy, deploy `closed` with the coordinated Test/production release procedure. A switch only reloads Nginx, so run `systemctl start academy-profile-publication-guard` right after the deploy and verify its success. Then verify the root-owned marker `/persistent/data/academy-profile-publication/private-policy` exists, no `released-*` flag remains under `/run/academy-profile-publication`, and all six rankings and profile projections are closed. The directories allow Nginx to check existence; the file contents are root-only. Closing never deletes the marker.

Then carry out the separately reviewed V8 visibility activation using the current backend tool and verify all existing accounts are private. This module performs no visibility writes. Right after that activation, set `academy.backend.profilePublication.activated = true` for the host and deploy it while still in `closed`; from then on the configuration rejects `prepare` and a disabled module, and every guard run renews the marker. Check compatible Readers/clients, legal text, warm application cache withdrawal, private learning paths and zero financial/mail side effects before selecting `shared`. After deploying `shared`, run `systemctl start academy-profile-publication-guard` and verify its success and the `released-shared` flag; without it the surfaces stay closed until the timer run. If the policy check is uncertain, keep `closed`.

Only before activation, while `activated` is unset and the policy has never been active, an abandoned `closed` rollout may return to `prepare`: remove the marker, deploy `prepare` and run the guard. If the policy is active after all, the guard restores the marker at once and keeps rankings closed.

Read the actual CDN configuration before activation. `no-store` stops new storage; it does not purge old HTTP objects. Inspect personalized route responses with and without conditional/origin headers. Record actual purge results if a purge is required. Do not claim that earlier copies, screenshots or rendered pages disappear.

## Recovery

Never disable this module, remove its persistent fence, or select a pre-fence infrastructure generation after activation. Preserve the marker together with current databases and post-snapshot withdrawals/deletions. If restore evidence is incomplete, select `closed`. An activated database recreates a missing marker on the next guard run; an unavailable or unrecognized policy keeps the surfaces closed. An old snapshot cannot establish permission to publish.

`academy.v2Recovery = true` overrides publication to closed even if the normal configuration says shared; the guard runs in recovery mode and never opens. It retains the current packages, native migrations, schema and policy generation; existing recovery admission holds remain in force. Reopening requires the reviewed forward generation. Downgrading the privacy schema or merely turning Readers off cannot restore legacy rankings. Existing learning runtime recovery rules and writer holds continue to apply.

`.#checks` includes both tests. `.#profile-publication-config-tests` evaluates the modes, the `activated` host option, package mismatch and the guard wiring on the Test host; its expectations follow the capabilities of the current pins. `.#profile-publication-tests` runs a disposable PostgreSQL/Nginx VM with the real guard, timer and Nginx dependencies, covering HTTP errors, conditional reuse, internal ingress, persistent fences, inactive/unknown policy, database outage while Nginx starts, automatic reopening and mode switches including recovery. The VM uses synthetic fixtures; it does not prove live application or CDN behavior.
