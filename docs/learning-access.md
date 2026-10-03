# Shared learning access

The module is disabled by default and does not change existing host settings.
Deploy compatible Backend, Skills and Challenges versions before enabling it.
Frontend policy and daily status are server-owned; clients cannot opt themselves
into another cohort or claim Premium. When enabled, the Skills environment also
receives its existing per-audience Challenges secret for the internal historical
participation lookup. The endpoint returns only prior participation, not answers.

## Initial release with switches off

The initial release keeps `learningAccess.enable=false`, the Backend default
policy `legacy`, Skills database mode `off`, and
`DAILY_LIMIT_POLICY_ENABLED=false`. Normal learning must create no lesson-start
or start-request rows. Verify the effective settings and both tables during
test acceptance. Existing heart charging, sales and progress remain active.

The owner decided to use aggregated statistics from existing data. A separate
measurement phase with new start recording is not part of this release.
The dormant shadow mode remains available in code for separately reviewed
future work; its existence does not authorize activation.

For reference, the policy module can explicitly select a technical pilot:

```nix
academy.backend.learningAccess = {
  enable = true;
  policyMode = "shadow";
};
```

Skills keeps a database-owned `off|shadow|enforce` setting. Its additive
migration initializes `off`, limit `3`; deploys and service restarts never
overwrite an operator's later choice. Use authenticated internal
`PUT /skills/_internal/daily-limit` with `mode`, `limit`, `updated_by`, and
`note` to select `shadow`. Read the same endpoint to verify the state and
curriculum readiness. Public reverse proxies must continue rejecting all
internal endpoints.

Shadow records real lesson starts without imposing the new limit. Existing
heart and contract rules remain active. Such recording requires a separate
owner decision; do not activate it as part of the initial release.

## Deliberate activation

The owner must first approve the exact launch cohort and terms. An existing-account
transition requires its own approved notice and acceptance process.
The application requires a selected cohort **and** a matching accepted version
dated at or after `acceptedSince`; neither setting replaces consent. This
module preserves the registration terms version unless the explicit signup-only
selector below is configured. It never sends notifications.

After review, set `policyMode = "daily"`, `termsVersion`, `acceptedSince`, and
either explicit `userIds` or `registeredSince`. Keep these values in the
reviewed environment configuration. Supply `dailyDocuments` with the deployed
`termsPdfPath`, `termsSha256`, `withdrawalPdfPath`, and `withdrawalSha256`.
Backend verifies the exact bytes and version at startup; it rejects missing
originals and the previous r4 terms for a daily-policy offer. Existing accepted
offers retain their own originals. A version label alone never changes the
contract attached to a purchase. Skills permits `enforce` only when the
relevant courses have explicit curricula: a single quiz must not accidentally
consume a whole lesson allowance. Premium and genuine prior purchases remain
exempt, begun lessons remain usable, and legacy contractual access remains.

A registration-only launch uses `registrationTermsVersion` equal to the approved
daily version and a `registeredSince` cohort. For this signup-only launch,
use the same approved instant for `acceptedSince` and `registeredSince`. This maps only to Backend
`user.registration_terms_version`; keep its ordinary `user.terms_version`
unchanged for old account acceptance. Configure the frontend build with both
`NUXT_PUBLIC_REGISTRATION_TERMS_VERSION` and `NUXT_PUBLIC_REGISTRATION_TERMS_URL`
(`/docs/terms-and-conditions-<version>`), and publish that exact reviewed document.
Both frontend values default empty, preserving the existing signup. Keep the
override while its accounts exist; do not use a global version bump to migrate
old accounts. This prepares new registrations only, not a historical-account
opt-in or notice process. The dormant TermsGate is not mounted by the current app.

Stage on test, verify both old and new cohorts, then perform the separately
approved production release. Do not enable the new cohort against older
Challenges/Skills versions that still debit hearts or do not enforce starts.

## Recovery

To remove the new quota without restoring heart charges for daily-policy
users, set the Skills database mode to `off`. Leave the Backend daily-policy
cohort intact: reverting an accepted user's contract mode to legacy is not the
quota kill switch. Never restore a pre-migration binary until its schema and
new-policy behavior have been checked. Preserve start rows and original
purchase/heart receipts. No destructive rollback migration is required.
