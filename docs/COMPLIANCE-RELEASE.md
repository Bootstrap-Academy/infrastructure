# Coordinated application release and recovery

This procedure preserves durable contracts, financial identities, deletion work and original documents while coordinating compatible application releases. Select the exact sources and an operational release record before activation. Keep case records, credentials, actual deployment observations and release decisions in restricted storage; this public guide contains the reusable technical procedure.

## 1. Select and verify the exact release

Maintain the release manifest separately from the public repositories. It selects each application commit/tree, migration files, document versions and relevant infrastructure inputs. Record the final infrastructure commit externally because a commit cannot include its own final identity. Update the selection and digests when source files change.

Run the offline inventory from the selected workspace with the actual manifest path:

```bash
python3 infrastructure/scripts/release-preflight.py \
  --manifest /path/to/release-manifest.json > /tmp/academy-source-inventory.json
python3 infrastructure/scripts/release-preflight.py \
  --manifest /path/to/release-manifest.json --check-pins > /tmp/academy-pin-check.json
```

The first command requires the selected commits, clean worktrees and exact source hashes. The pin check additionally requires both prod/test locked source trees to match that selection. A mismatch blocks using those pins for the selected release. The checker accepts exact tree equivalence; it does not recompute NAR hashes or establish remote availability. It does not fetch, publish, migrate or activate anything.

Publish selected sources through the release workflow, select exact revisions for both prod/test inputs, let Nix resolve their hashes, and commit the lock/config. Verify again and retain a restricted release record: final infrastructure commit/tree and lock hash, every input revision/NAR hash, built derivations and closures, executable hashes/versions, frontend/dashboard build and deployment IDs, effective configuration, current/previous host closures and actual predeployment schemas. Local Git history or a cached old pinned build does not identify the running generation.

Prod uses `backend`, `events-ms`, `skills-ms`, `jobs-ms`, `challenges-ms`; test uses their `-develop` inputs. Frontend/dashboard releases are outside the Nix closure. Check their actual deployment branch triggers: a branch push can activate a Pages deployment automatically. Compatible backend/service readiness must precede those frontend/dashboard pushes. Local evaluation may use exact local source overrides with `--no-write-lock-file --offline` and no remote builders. An unavailable cached input is a reported limitation, not a current service build.

### Compatible interfaces and documents

- New signup and expressly accepted new purchase/renewal contracts select AGB `2026-09-r2`. `purchase-document-manifest-2026-09-r2.json` explicitly pairs that AGB with unchanged withdrawal `2026-09-r1`. Existing records and older PDF bytes remain original. Existing accounts receive no global TermsGate prompt. Publish compatible code, current pages and attachment selection together; keep the labelled historical r1 page reachable. An informational account notice does not amend an existing agreement.
- Staff original reads, inventory, retention paging, hold review and determinations remain available. Authenticated staff dispatch refuses `cash_basis_review`, `reserve`, `split_cash`, `record_cash_payment` and `outcome` as unsupported (400). Do not use SQL/old clients/CLI to bypass this boundary. Existing pending receipts, reservations and uncertainty remain evidence; an empty queue or a refused call does not prove settlement.
- Four scoped charged Challenges POST routes (MCQ, matching, Questions attempts and coding submissions) are absent. Ordinary routes, scoped GETs and the check-only example route remain. Retained exercise access has limited capabilities; do not advertise the removed mutation paths.
- Wallet restoration requires the exact admitted target and original operation identity. Do not substitute a destination, invent a new command ID or manually credit an uncertain operation to resume service.
- Check public document content and its stated operating facts separately. Source configuration and a successful build do not establish provider arrangements, actual retention execution or completed recovery.

## 2. Inventory schemas and every writer

Use the actual per-host units/wrappers from the recorded closure. The backend Nix wrapper
switches to user `academy` and supplies `ACADEMY_CONFIG`, a colon-separated list of secret
template and generated TOML. Do not substitute repository `config.toml`, print secrets,
or run `check-config --verbose` into evidence. Record protected config file identities/
digests and nonsecret effective endpoints/settings. `academy --version`, `academy migrate
--help`, `academy migrate down --help` and `academy task --help` require no database.
Match the executable to the release build.

Databases are `academy`, `academy-events`, `academy-skills`, `academy-jobs` and
`academy-challenges`. The infrastructure targets PostgreSQL 18. Match the actual target major version in rehearsal. Separate any database
major upgrade from app recovery; never select an old generation whose PostgreSQL binary
cannot read the existing data directory.

For a future authorized host inventory, these read-only commands use the actual tracking
tables. Save stdout to restricted evidence and securely transfer it to the workspace:

```bash
sudo -u postgres psql -X -v ON_ERROR_STOP=1 -qAt -d academy \
  -c 'BEGIN READ ONLY; SELECT name FROM _migrations ORDER BY name; COMMIT;' > backend-applied.txt
sudo -u postgres psql -X -v ON_ERROR_STOP=1 -qAt -d academy-events \
  -c 'BEGIN READ ONLY; SELECT version_num FROM events_alembic_version ORDER BY version_num; COMMIT;' > events-applied.txt
python3 infrastructure/scripts/release-preflight.py --check-pins \
  --manifest /path/to/release-manifest.json \
  --backend-applied backend-applied.txt --events-applied events-applied.txt > schema-plan.json
```

The Python command runs on the workspace. Missing tables are errors to investigate, not
permission to declare an existing database empty. Empty files are valid only for separately
verified new databases. The checker rejects unknown/duplicate/gapped backend names and
unknown/multiple Events heads. Also retain schema-only dumps of **all** databases, migration
tables, extensions/roles, and compare the isolated migration result to the release schema.
Matching migration names does not prove matching structural schema or data.

Actual CLI/migration behavior:

- Backend `serve` applies all pending migrations by default (`database.run_migrations=true`).
  False refuses startup if migrations remain; it is not a read-only server mode. `academy
  migrate up` applies pending migrations; optional count is `--count/-n`. No target-name or
  dry-run switch exists. `migrate list` creates `_migrations` if missing, so prefer the SQL
  above for read-only evidence. Names sort lexicographically at compile time; the tracking
  table stores names, not SQL checksums. The manifest hashes actual up/down files.
- Each backend up/down has its own transaction. Later failure leaves earlier migrations
  committed. Re-inventory after failure. Do not edit `_migrations` or bypass guards. The old
  positional down syntax is unsupported; **a down count does not establish safe recovery**.
  `reset` and `demo --force` destroy data and are only for disposable fixtures.
- Events runs its release's `alembic upgrade head` in `academy-events.service` pre-start,
  with that release's directory/environment. Tracking table is `events_alembic_version`;
  the selected current chain ends at `l3ordinarycancel001`. Historical booking-payment
  provenance preserves known/unknown evidence; never stamp a head or guess paid amounts.
  Use the complete manifest chain, including later retained-right, benefit and cancellation
  migrations. Skills/Jobs also migrate in pre-start; Challenges has its own migration
  pre-start. Preserve every service's history and verify its actual release entrypoint.

Inventory, drain and stop all application writers, including:

| Actual service (and timer where shown) | Background/indirect writes |
|---|---|
| `academy-backend` | HTTP, capture, original/archive writes and Premium charge-on-read; PayPal and per-service erasure recovery immediately and every 60s; declaration/schedule, purchase-confirmation and moderation-delivery recovery immediately and every 30s |
| `academy-task-refresh-premium` + timer | Confirmation outbox and renewal debits, daily default |
| `academy-task-prune-database` + timer | Data/evidence pruning, hourly default |
| `academy-task-prune-documents` + timer | Register/archive pruning, monthly default |
| `academy-events` | HTTP booking/cancellation/deletion; booking-payment, settlement and expired-webinar/slot payout recovery immediately and every five minutes; original/ordinary cancellation and booking-confirmation recovery immediately and every 30s; earned-benefit delivery immediately and every 5s |
| `academy-events-sweep-deleted-users` + timer | Deletion/refunds, 03:25 plus randomized delay, persistent timer |
| `academy-skills` | Service APIs, course access/purchase effects, retained progress and benefits; purchase fulfillment/reporting recovery immediately and every 30s |
| `academy-jobs` | Existing service API and service-owned writes; unchanged application source is still an active writer |
| `academy-challenges` | Ordinary/scoped service APIs and authored/moderated state; durable benefit dispatch starts immediately and loops every 5s, including remote effects and local acknowledgement/observation writes |
| `academy-skills-sweep-deleted-users`, `academy-challenges-sweep-deleted-users` + timers | Deletion/content effects, 03:10/03:40 plus randomized delay |
| Manual CLI, containers, other hosts, admin APIs | `task retry-paypal-payments`, `task retry-user-deletions`, `task retry-contract-confirmations`, `refresh-premium`, administrative coin/document commands and old payment/refund writers outside these units |

Stopping timers does not stop running oneshots or in-process workers. Closing browser
checkout does not stop captures. Check processes, containers, units, database sessions/
transactions and operator jobs; drain requests before stopping. Record killed/timed-out
operations as uncertain. An old process may have captured remotely just before it stopped.

## 3. Establish a recoverable boundary

Assign an actual release/recovery operator and financial/erasure reconciliation owner;
record contacts/escalation thresholds. This document makes no appointment. Before admitting
affected writers, inspect actual pending captures, legacy charges/refunds, deleted-recipient
claims, deadlines, holds and delivery failures; confirm the effective SMTP/provider/internal
auth configuration. Unresolved financial facts remain unresolved: the current staff API
does not execute the five excluded settlement operations. Keep affected writes closed
when their reconciliation conditions are not met. Record actual production inventory and unresolved historical settlement; a UI cannot substitute for these operating checks.

Close public **and internal** application ingress using the operator's reviewed maintenance
configuration, preserving static statutory/contact information and an actually staffed
declaration intake/receipt procedure. Preserve exact receipt times/content during the outage.
Suspend operator/external automation writes; drain and stop every writer above. Include
already accepted captures/mail in reconciliation. Suspend retention and backup prepare/
prune jobs during the snapshot interval so evidence cannot rotate away; record prior states.

Take a protected complete snapshot **after quiescence**, and a second snapshot of the
current incident state before recovery. Preserve originals separately. Capture every
PostgreSQL database and roles/schema/sequences; relevant `/persistent/data` and
`/var/lib/academy/{invoices,credit_notes,final_statements}` files; service uploads/content;
external storage actually used; protected recovery config/credentials and build identities;
outage intake and deletion/moderation/provider records. Record checksums, UTC cutover,
database boundaries and unique snapshot IDs. Read-only external lecture mounts are not
automatically part of this host's backup. Restrict copies like live personal data.

Configured backup behavior: `prepare-backup.service` runs `pg_dumpall` into
`/persistent/data/backup/postgresql-dump.sql`, takes a read-only Btrfs snapshot at
`/persistent/data/.snapshots/backup`, then triggers the configured restic targets. Raw
`/var/lib/postgresql` is excluded from restic. This is **not WAL/PITR**, nor an atomic
cross-database/provider snapshot while writers run. The reused local snapshot path is
not a durable release snapshot ID. Configured retention keeps 48 hourly, 14 daily, eight
weekly and 12 monthly snapshot groups; those are counts, not fixed deletion ages after an
account deletion. Job/retention config proves neither backup existence
nor successful recovery. Identify an actual restic snapshot, verify its manifest/dump
and restore into an isolated empty target of a compatible PostgreSQL version. Block
production PayPal, SMTP, service endpoints, webhooks and user traffic there. Do not start
backend/Events with production egress against restored state: startup performs financial
work. Preserve whole databases/files, not only pending records or selected new tables.

## 4. Rehearse and activate in order

Rehearse the selected closure/config against the actual predeployment schema in isolation,
with synthetic/local providers and SMTP. Unit tests and local builds do not establish a production restore rehearsal. Use a separately controlled target for the required release checks. Exercise interrupted migrations, failed activation, retained
financial/consent/declaration/moderation/deletion state, same-order payment and same-key
Events response-loss recovery, and snapshot restoration. Compare full rows/ledger/access/
file hashes. A health endpoint or an OpenAPI string alone cannot prove these invariants.

Both prod/test host configurations set `academy.releaseHold = true;`. Review the exact
final commit, manifest and selected closures before activation. The
[release-hold module](../modules/release-hold.nix) adds `ConditionPathExists` to all eleven
application writer services above. Admission files live in root-owned mode-0700
`/run/academy-release-allow`. The module creates **no admission files**. Timers may fire but
cannot start a held service. This prevents Events pre-start/recovery racing the backend.
Removing a file does **not** stop an existing process. The hold does not cover manual CLI,
other-host processes or ingress. Reboot clears admission files and holds all writers again.
Keep the hold until normal automatic startup is separately reviewed/rehearsed.

Inspect all eleven generated service conditions in the actual held closure. Record help
from pinned deploy-sh `5c9c65ffbb689c2f193edc628c2e6d95ca386d4f`: `--dry-activate` builds,
contacts/copies to hosts and runs remote dry activation; it is **not offline rehearsal**.
`--test` activates services; `--boot` changes boot default; default `--switch` activates
and changes the system profile. None provides database rollback. Test/sandkasten builds
use prod, so even building them may contact prod. Use local isolated builds before
authorization. SSH follows configured WireGuard admin access; do not assume this
workstation has access or alter access policy as part of this procedure.

During an authorized maintenance window, after quiescence and verified snapshots:

1. Stop the inventoried timers/services and other writers. Record the old closure and
   process disappearance. Ensure admission files from any previous held release are
   absent; remove only those admission files, never application data. Activate the reviewed
   **held** closure, for example the pinned `deploy --switch test` from its exact checkout.
   Inspect all eleven services: each must be inactive with unsatisfied admission conditions.
   One Nix closure does not establish service startup order. Stop on partial activation.
2. While all services remain held, run the **new recorded system wrapper**
   `/run/current-system/sw/bin/academy migrate up`. This changes the database without
   contacting PayPal. Re-inventory and compare schema/data to the recorded plan. Legacy
   renewal must remain archived/disabled while preserving paid access/ledger. The complete
   selected chain must preserve payment, commercial identity, hold and original-document
   evidence. Any discrepancy requires a forward investigation.
3. Review pending/legacy records first using `academy task list-paypal-payments` on the
   migrated schema (read-only). Staff API reads require the running backend, so they cannot
   substitute for this held-state inventory. Only when financial/release gates permit recovery, admit
   backend with `install -o root -g root -m 0600 /dev/null /run/academy-release-allow/academy-backend`,
   then `systemctl start academy-backend.service`. **Startup immediately permits capture of started
   orders, coin fulfillment and receipts**, even with public ingress closed. No read-only
   recovery flag exists. `task retry-paypal-payments` is a payment/write command. After
   admission, use supported staff original/status reads to inspect the running current state.
4. Verify the actual backend build/schema and authenticated keyed endpoint
   `PUT /shop/_internal/coin-operations/{operation_id}/{user_id}` using synthetic identities
   in rehearsal. Verify shared/per-audience JWT configuration on all participants; the
   optional separate-secret flag is not assumed enabled. Schema/auth/deduplication must
   work before admitting Events.
5. Admit/start `academy-events` using its matching admission filename. Its pre-start applies
   the recorded Alembic chain, then immediate settlement/payout recovery begins. Verify
   version, persisted batches/operation IDs, backend receipts and backlog. **No old Events
   writer may coexist.** New Events against old backend retains failed obligations but
   cannot complete refunds. Never fall back to unkeyed POST or mint new UUIDs for old work.
6. Admit/start Skills, Jobs and Challenges individually; verify migrations/internal calls.
   Skills immediately resumes purchase work; Challenges immediately dispatches durable
   benefits and repeats every five seconds. Review their original IDs and pending outcomes
   before admission; service startup itself is a write boundary. Enable admission for each
   sweep/refresh/prune service and restart its previously stopped
   timer only after reviewing backlog/retention/erasure gates and next firing. Overdue
   persistent timers may fire immediately. Resume backup jobs deliberately after snapshots
   are protected. Match each admission filename to the service name in the table.
7. Complete test before a separately gated prod window. Sandkasten is a separate execution
   host, not rehearsal of application migrations. Review its exact changes separately;
   avoid a broad multi-host activation as a single step.
8. Publish the recorded compatible frontend only after backend/Events/Challenges verification.
   [Frontend guidance](../../frontend/docs/DEPLOYMENT_RUNBOOK.md) describes repository
   topology; use reviewed exact final revisions and production config, not historic refs.
   Publish the compatible dashboard and coordinated legal pages/attachments; record Pages
   IDs. Reopen ingress and monitor payments/receipts/renewals/settlements/declarations/
   deletion against pre-release evidence. Real purchases, cancellations and password-reset
   emails are not harmless health probes.

Historical unkeyed coin calls are not retroactively idempotent. Include all coin writers in quiescence/reconciliation.
Never replay an ambiguous old POST because its booking still exists.

## 5. Recovery preserves everything written since release

Default: close ingress, quiesce writers again, preserve the incident snapshot and diagnose
the actual partially activated schema/services. Keep databases, archive files and durable
identities. Repair config or deploy a reviewed **compatible forward fix** using the hold
and staged admission. Verify it on an isolated copy of the current incident state. A binary
must preserve the selected schema and current original/recovery semantics, including
saved browser command bodies and keys. Pre-protection payment/refund/identity binaries
are not compatible fallbacks. Adding
`users.newsletter` back restores one field, not old evidence or safe payment behavior.

Renewal downs refuse retained renewal archive/agreement evidence; keyed-coin downs refuse nonempty
`internal_coin_operations`; payment recovery downs refuse `paypal_payments`/`paypal_legacy_reconciliation`
evidence. Events `c6e1700ab001` refuses nonempty settlement batches. Later learning-creation, invoice-identity/disposal and wallet-target migrations also
refuse unsafe descent; hold-review downgrade preserves incarnation/revision history or
refuses it. These are scoped guards, not blanket preservation: older downs still drop declarations, consents, financial
documents, audit and user fields. Do not bypass guards, delete migration records, replace
the old count, switch to an arbitrary previous Nix generation, revert one historic PR or
force-push an old frontend as recovery. An old frontend can discard unresolved order IDs
and encourage another charge; preserve the recovery UI or keep checkout closed.

If full restore is the only viable option, restore into an **isolated new target**, preserving
the original current/incident databases/files. Do not restore just Events, just backend or
just archives over current state. Reconstruct and reconcile the entire post-snapshot delta
before starting financial workers or opening traffic. Restore rolls back later local money,
receipts, consent, deletion and moderation; external captures/email acceptance do not roll
back. Restored legacy orders may double-charge; missing keyed receipts may double-credit.
A successful restore command does not demonstrate safe recovery.

Keep complete databases/files as the authoritative preservation set. This verification index
is **not an export allowlist**:

| Domain | Evidence that must survive/reconcile |
|---|---|
| Money/purchases | `coins`, `transactions`, `paypal_coin_orders`, invoice/user-number sequences, actual provider order/capture/refund outcomes and original historical amount/VAT/recipient facts |
| PayPal payment recovery | All `paypal_payments`, including unstarted/started/captured/fulfilled/delivered states; immutable request UUID/first-attempt time, capture proof, stored result and receipt attempts; every `paypal_legacy_reconciliation` row. No fresh capture key or inferred failure |
| Keyed Events settlement | All `events_settlement_batches`, `events_coin_operations`, original event/booking/recipient/amount, attempts/completion/notification state; matching backend `internal_coin_operations` receipt/result. Retain completed records too; reconcile pre-key effects separately |
| Financial archives | `financial_documents`, recorded tax/consent/settled metadata and invoice/credit-note/final-statement bytes/checksums. Investigate missing/orphan files; do not regenerate historical VAT or delete them blindly |
| Premium/consent | Paid `premium`, subscription state, all `premium_legacy_renewals`, agreements/delivery/cancellations/attachments/deadlines; user terms/refusal/age observations and `withdrawal_consents`. Cancelled/missed agreements never reactivate; deadlines never reset |
| Declarations | All `contract_declarations`, reference/receipt time, reasons/order details/requested dates, staff notes/state and available delivery evidence; outage intake. Email failure never invalidates the receipt |
| Moderation/deletion | `admin_audit_log`, Challenges reports/bans/visibility/authored content, all service deletions/erasure requests and account/opt-out/token state. Reapply later erasures/restrictions before reopening; do not resurrect accounts/content or valid calendar/session links |
| Retained commercial work | Complete commercial case/claim/identity/original/journal tables, hold incarnation/revision/history, determination and disposal evidence, service rights/grants/benefit components and acknowledgement history; original saved command bodies, selected identities, receipts and uncertainty. A live page or latest review is not complete historical recovery evidence |

Use separately reviewed reconciliation tools that retain identifiers, immutable snapshots,
outcomes and audit provenance in one coherent restored state. The current CLI has **no
general lossless delta importer, legacy-payment adoption command or cross-database restore
reconciler**. If tools/facts are missing, preserve copies and keep affected writers closed
while a reviewed forward repair is built. Do not bypass immutable triggers or manually
credit to clear backlog. Deleted recipients require an attributable reviewed claim; a
retained UUID alone is not a verified payee, and account recreation is not reconciliation. Apply a reviewed cache/session/calendar invalidation plan and all
post-snapshot erasures across databases/files before exposing recovery.

Independently verify one matching capture/credit per payment, one backend receipt per
completed Events operation, balances/ledger/sequences, document/register equality, immutable
consent/deadlines, every declaration receipt and later moderation/erasure outcome. Preserve
intake throughout recovery and assign unresolved identities to an actual operator. Only
then admit compatible workers. SMTP may repeat the same receipt after uncertain acceptance;
payment/coin identity must not change.

## 6. Account erasure recovery and unresolved claims

The backend now queues `user_deletion_work` in the account DELETE transaction
(migration `2026-09-07-200000_durable_user_deletion`). Each of Skills, Challenges and
Events has its own pending row, even if its URL is missing. A backend in-process
worker runs immediately at startup and every 60 seconds, independently of payment
recovery; a pass attempts up to 100 distinct due rows. Before each remote request,
it uses `SKIP LOCKED` to claim a row and separately commits an incremented attempt
generation and a 60-second lease/retry time. HTTP delivery is capped at 30 seconds
(or the shorter configured service timeout). A successful service acknowledgement
removes only that row and only if its attempt generation still owns it. Failed
delivery defers retry by 60 seconds. A rejected acknowledgement COMMIT or worker
crash preserves the already-committed scheduling, allowing older untouched work
to advance in later passes and fresh processes. Expired leases are reclaimed with
a new generation; late success/failure from a superseded worker cannot change it.
Attempts count reservations, including a possible crash before HTTP. An uncertain
claim COMMIT sends no HTTP; recovery checks the durable state on a later pass.
All three service deletion handlers must remain idempotent, including immediate
fan-out/recovery overlap and a paused worker that outlives its lease. Do not reset
attempt generations or force active leases due. Stop/drain old and new deletion
workers before binary replacement; older workers do not follow this ownership rule.

`academy task list-user-deletions` reports aggregate count/oldest request per service;
`academy task retry-user-deletions` performs a bounded pass with database/internal
service credentials and does not require a functioning cache or SMTP connection.
Missing URLs are pending work, not evidence that a service has no retained data.
Assign backlog/age alert ownership and investigate failures against the 30-day
published erasure bound. The `academy-backend` admission hold covers this
in-process worker; there is no new timer/unit. Manual retry commands are writers
and must also be excluded while that hold is active. The hold is unchanged.

Retain this additive queue during forward repair/restore; its downgrade refuses
pending work. Restore reconciliation must include pending erasures and reapply
post-backup deletions before reopening. Earlier deletions without a queue remain
covered by the per-service keyset sweeps, which now isolate individual failures.
No historical inventory or completed next-night cleanup is inferred.

Financial operation evidence is independent of account erasure work: a deleted
recipient's original event/payment claim remains unresolved when the backend
returns 404. Known and unknown student booking payments retain a dated deletion
marker without introducing a refund rule. Affected unresolved claims still require verified claimant matching, payable destinations
(including already-deleted users), purpose-bound evidence and a separately supported
settlement process before any settlement execution. The current API exclusion remains in
force; no general payout workflow is approved by this runbook. Some deleted event recipients have only a UUID and booking/payment
references: the existing named final statement is created only for unused purchased
coins. This cannot establish a new cash payee. No claim is deemed settled or forfeited
by this release procedure. Apply the existing financial/legacy/retention gates.

Verify the final manifest and both hosts' pins against the selected cut before any
authorized activation. Unresolved claims remain owned review work, not implied completion.


## 7. Declaration writer and operational gate

`academy-backend` also starts declaration schedule recovery and its durable confirmation outbox immediately and every 30 seconds. `academy task retry-contract-confirmations` runs a bounded pass manually. Both are writers under the existing admission/hold rules; quiescing only Premium timers does not stop them. No new systemd unit is needed. Exact-agreement cancellation also runs inside Premium paid-period reads/writes, with the same per-user serialization as renewal and manual extension.

Before activation, assign and evidence immediate coverage of `/dashboard/declarations`: receipt time, the requested Berlin calendar date, submitted identification/details, unverified account match, receipt-time/changed paid periods, exact agreement, schedule and delivery state are visible. A valid declaration's effect is not postponed until staff approval. Resolve unverified/extraordinary/contradictory cases promptly using the original receipt and applicable contract; compare any later debits and preserve already-paid access. Refunds/restitution requiring financial judgment need a separate attributable decision; they are not implied automatic refunds. Staff recording external completion must identify the performed action and verified communication evidence. Do not call an unresolved date or an SMTP acceptance a completed legal determination.

Claims commit before SMTP, with a 60-second lease and monotonically increasing attempt generation; the call is capped at 30 seconds. Failed acknowledgements cannot roll back scheduling or let an old worker overwrite a replacement. Each pass considers at most 100 distinct due messages, and failures defer rather than starve later work. Monitor logged unresolved declaration counts/oldest receipt and outbox counts/oldest creation, plus admin per-message attempts, next attempt and generic error. Repeated delivery failures require operational intervention; no finite retry count silently discards a valid receipt. SMTP acceptance only proves the configured server accepted the message. An accepted message whose acknowledgement is lost can be sent again with the same immutable text and Message-ID; exactly-once inbox delivery is not claimed.

The additive `2026-09-07-210000_complete_declarations` migration retains declaration capabilities (hash only), exact message bytes, account/paid-period observations and schedules. Original declaration/message bytes cannot be updated; evidence-bearing downgrade is refused. Legacy rows lack reliable delivery history and are not marked delivered or retrospectively mailed by migration. Inventory and reconcile legacy unresolved cases before release. Account deletion removes the live account reference while necessary original identifiers/contact/evidence remain; public capability lookup still returns only submitted facts. Unresolved delivery/handling/schedules are protected from pruning. Final retention/legal-hold policy remains a separate release dependency.

Record the selected commits, completed operating checks and activation decision separately. Keep the admission hold in place until the applicable schema, financial, erasure and recovery prerequisites are met.
