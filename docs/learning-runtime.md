# Preparing the lesson runtime

These optional modules use existing application hosts, PostgreSQL, systemd and
Nginx. Both switches default to **false**. Current application pins are retained;
this preparation does not start a worker or publish a lesson.

## Separate coding execution

After pinning and testing the application release that supports durable leases
and the `api`/`worker` commands, enable
`academy.backend.codingExecution.enable = true` on the test host first.
The normal `academy-challenges` unit starts the API, and
`academy-challenges-worker-1` runs the executor queue without an HTTP listener.
The same reviewed package supplies both roles and the native migration binary.

The existing API `ExecStartPre` remains the sole automatic migration authority;
workers do not migrate. Each worker starts after the API and checks that its
startup succeeded. It inherits the API environment, credential files, user,
hardening, resource and runtime settings, with separate process commands.
`Wants`/`After` and the explicit startup check intentionally avoid coupling
running workers to every API restart. Stopping the API therefore does not stop
workers: a coordinated maintenance operation must stop both roles.

One worker retains the existing total capacity: test has two slots, production
four. To change capacity, explicitly adjust `codingExecution.instances` and/or
the existing `challenges.coding_challenges.max_concurrency`. Their product is the
per-host configured capacity; multiple hosts also share the current Sandkasten
service and its finite capacity. This is independent process scaling on the
existing host, not evidence of additional machines or greater measured throughput.
Admission bounds and lease/retry/deadline settings remain in the application
configuration. Do not increase concurrency without reviewing executor and
database capacity.

Workers participate in `releaseHold`, `v2Recovery` and
`continuousLearningRecovery` with their own per-unit admission condition. No
admission file is created by configuration. The current recovery packages and
schema remain the recovery baseline; a historical whole-system rollback is not
automatically compatible.

For the first transition, close admission and stop **all** old embedded workers
before starting the leased workers. Keep the API and all worker units held while
applying the additive migration once with the reviewed native runner. Verify
the schema and existing results, then admit the API and workers. Subsequent
routine API restarts still execute the existing idempotent migration check.
Never run migrations from each worker. A process failure may allow remote
sandbox work to run again after lease expiry; only the current lease can commit
the authoritative result and rewards.

## Static module packages

`academy.backend.lessonModules.enable = true` prepares
`https://<existing-api-host>/lesson-modules/<sha256>/<asset>` on the existing Nginx
host, persists `/var/lib/academy-static`, and configures that HTTPS origin in
Skills. It also installs the internal `academy-publish-learning-module` helper.
No registry record or content definition is automatically created.

Build browser-ready ES modules with the frontend's `build-learning-module.mjs`
using this `/lesson-modules/` base URL. Its output contains the assets,
`module.json` with exactly `{id, api_version: 1, entry_url}`, and `manifest.json`
with `{artifact_sha256, definition, files}`. The artifact digest is SHA256 of the
UTF-8 `JSON.stringify({definition, files})`; property order and the original
definition are preserved. It is an immutable publication address, not lesson
versioning.

Copy the reviewed package to a private staging directory on the intended host,
then use the local helper:

```sh
academy-publish-learning-module --package /reviewed/<sha256> \
  --root /var/lib/academy-static/lesson-modules \
  --base-url https://<existing-api-host>/lesson-modules/ --check
academy-publish-learning-module --package /reviewed/<sha256> \
  --root /var/lib/academy-static/lesson-modules \
  --base-url https://<existing-api-host>/lesson-modules/
```

The helper performs no network access or service/registry action. It verifies
all file hashes, byte lengths, inventory, artifact digest, directory name and
descriptor URL. Publication uses an atomic directory rename. An existing
artifact is reusable only if the complete inventory and file hashes agree;
existing assets are never overwritten. Hidden files, symbolic links, controls
and backslashes are rejected; normal Unicode names and spaces are supported.
Staging directories are inaccessible through the hash-only URL route.

The publisher creates only the final publication root and explicitly sets a new
root to `0755`, including when the caller uses `umask 077`. Its parent must
already exist with permissions suitable for the web server. Existing private
roots are rejected without changing their permissions; no existing parent is
opened implicitly. The Nix tmpfiles rules prepare both configured public
directories with `0755`. Artifacts and nested asset directories are sealed to
`0555`, files to `0444`, independently of the caller's umask.

After actual GET/HEAD verification on the target host, register the reviewed
`module.json` through Skills' internal `python -m api.register_lesson_module`
CLI using its normal service environment. There is no public registration or
upload API. Publish files before registering their reference. A failed
registration leaves harmless unreferenced files; recover a wrong descriptor by
reviewing and replacing the registry reference, not overwriting an immutable
artifact. Keep referenced artifacts; cleanup needs a separate reference audit.

Nginx provides ES-module and asset MIME types, public GET/HEAD CORS, immutable
success caching, and actual 404 responses without API/SPA fallback or immutable
404 caching. Directory listing and symlink delivery are disabled. These are
public first-party code files, not private learner work or authorization data.
The reviewed code and its imports still execute in the shared web player.

This configures origin hosting and HTTP cache headers only. It does **not**
create a Cloudflare cache rule, switch DNS proxying or prove CDN cache hits.
Those existing-provider settings must be checked separately at release time if
edge caching is desired; no new paid service is required for this preparation.

## Lesson engine packages (API 2)

`academy.backend.lessonContent` (only Test enables it) serves packages of the
lesson engine from a session-free origin outside `bootstrap.academy`, as the
frontend requires (`lesson-protocol/browser.ts`). On Test the host is the
public IPv4 address of the machine: the NixOS acme module orders a Let's
Encrypt certificate for this IP identifier with the `shortlived` profile and
renews it once half of its lifetime is left; the vhost is the default server on
port 443 because browsers send no SNI for an address. The module sets Skills'
`ENGINE_CONTENT_ORIGIN` to `https://<host>`.

A package is the directory `<package_hash>` with the protocol manifest as
`manifest.json` and exactly its assets; `package_hash` is SHA-256 of the
canonical JSON of `manifest.assets`. The module installs the helper
`academy-publish-lesson-package` (`scripts/publish-lesson-package.mjs`; the API 1
publisher stays unchanged on every host). Install a package below
`/var/lib/academy-lesson-content/packages`:

```sh
academy-publish-lesson-package --api 2 --package /staging/<package_hash> \
  --root /var/lib/academy-lesson-content/packages --check
academy-publish-lesson-package --api 2 --package /staging/<package_hash> \
  --root /var/lib/academy-lesson-content/packages
```

The publisher checks the directory name, the manifest (at most 65,536 bytes),
paths and media types of the protocol, an HTML entry, the complete inventory,
every size and hash, and at most 1,572,864 bytes in total; it installs
atomically with `0555`/`0444` and reuses identical bytes. Nginx serves only
GET/HEAD of `/packages/<hash>/…` without query, listing, symlinks or redirect,
with the media types of the protocol, the content security policy the frontend
requires of the entry (`frame-ancestors` is the frontend of the host),
`Access-Control-Allow-Origin: *`, `Access-Control-Expose-Headers:
Content-Security-Policy`, `nosniff`, `no-referrer` and immutable caching, and
without the global `X-Frame-Options`. These are public bytes; the hidden cases,
the evaluator and the probe plans stay in the server document of Skills.

## Verification and release

`node --test tests/publish-lesson-package.test.mjs` checks the API 2 helper:
the package hash against a vector of the frontend's canonical JSON, sealed
installation and reuse, and refusal of every package that is not exactly its
manifest. `node --test tests/publish-learning-module.test.mjs` checks immutable reuse,
tampering, unexpected files, origin mismatches, symbolic links, Unicode assets,
public traversal under `umask 077` and preservation of existing private roots.
`tests/learning-runtime.nix` evaluates disabled host parity, enabled roles,
capacity and every worker recovery condition against an explicitly pinned flake.
Use pure offline evaluation with import-from-derivation disabled. The existing
Morpheushelper changes and all unrelated pins remain part of the baseline.

Before any actual rollout, bind the reviewed application pins, normal and
recovery systems, migration inventory, writer/worker list and static artifacts;
complete the normal release checks and budget gate. Test API requests while the
executor is stalled, worker restart/lease recovery, no duplicate rewards, module
lazy loading and actual static responses. Then perform the standard host
`deploy --check` and `deploy --eval --diff` and reconcile infrastructure main.
Local evaluation and fixture checks are not production deployment evidence.

The unit ordering behavior follows the upstream
[systemd unit documentation](https://github.com/systemd/systemd/blob/main/man/systemd.unit.xml)
and [service startup documentation](https://github.com/systemd/systemd/blob/main/man/systemd.service.xml).
