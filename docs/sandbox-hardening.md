# Sandbox isolation and artifact budget

`academy.sandboxHardening.enable` defaults to `false`. With the option disabled,
the existing sandbox service and all host system outputs are unchanged. Enable
it only on a host that also enables `services.sandkasten`.

The enabled module runs the supervisor and NsJail under `academy-sandbox`.
NsJail's inner UID/GID 65534 map to that unprivileged host account. systemd
delegates only the service's own cgroup subtree and places the supervisor in a
separate subgroup. A local NsJail launcher selects that subtree; upstream code
and the pinned binary remain unchanged. Child memory, swap, PID, execution-time,
file-size and network limits still come from the existing Sandkasten settings.
The whole service has a 4 GiB memory limit, no swap and a 1024-task limit.

The program cache is a service-required tmpfs mount at
`/var/lib/sandkasten/programs`, with mode 0700, a 512 MiB byte budget and 32768
inodes. `cacheMiB` and `cacheInodes` configure these two aggregate limits.
The mount permits executable artifacts and sets `nodev,nosuid`. It does not
erase previously cached files beneath the mount. The existing TTL pruner
reclaims expired programs; per-file limits remain separate from the shared
budget. The mount is required before startup, so a mount failure prevents
unbounded fallback to the host filesystem.

## Activation gate

A shared cache limit can reject otherwise valid compilations when unrelated
retained artifacts occupy capacity. The pinned sandbox returns this as
`400 compile_error`, including `No space left on device` in compiler diagnostics.
Before connecting learning workers, the caller must classify this as a
technical failure with a free retry, without an incorrect-answer verdict,
heart debit or XP effect. Keep the option disabled until that handling is
verified. Production activation needs the normal release approval.

The production sandbox is currently shared with Test. Acceptance of a changed
sandbox configuration must use an isolated Test executor, bound to loopback on
a separate port, before changing production. Keep the Test worker URL on its
existing executor until the caller fix is merged and accepted.

## Verification

`nix build .#checks.x86_64-linux.sandbox-hardening` runs real Python, Java and
Kotlin through the pinned API and NsJail in a VM. It checks host UID/GID maps,
concurrent cgroups and resource limits, capabilities, network isolation,
byte/inode exhaustion, cleanup, TTL pruning and service restart. A valid Java
compile is tested before cache saturation, during unrelated cache occupancy,
and after pruning. The test uses a 32 MiB / 256 inode cache to keep exhaustion
inside the VM. It records the caller activation gate explicitly.

The same VM check is included in the repository's `packages.*.checks` target.
Before release, compare disabled normal/recovery outputs and derivations with
the selected base, and verify the enabled mount and resource settings on the
actual target. The VM does not establish a sandbox escape-proof system or a
live worker integration result.
