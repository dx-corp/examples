# Account brief application

A CRM event handler submits one request. A separate worker resumes its private
checkpoint, reports progress, validates the final brief, and displays the
referenced receipts. Python and TypeScript use the same checkpoint and result
format, so a restarted worker can use either language.

Use a workspace with connected CRM data, a selected model, and a policy that
permits CRM reads for this job. The application neither provisions these nor
grants access. Store the task credential in your existing server secret manager.

## Trigger and background worker

Create a private state directory on a durable local filesystem. Keep one writer
per checkpoint; your event handler and worker must not run concurrently for the
same path. Map a business event to one stable trigger ID and one unique path.
An existing path means recover that request. Use a new path and key for new work.

```sh
mkdir -m 700 briefs
# The event handler exits after acceptance; it does not wait for a model.
python -m deixic.examples.account_brief start briefs/crm-event-001.json \
  --account 'Example account' --trigger crm-event-001 --structured
# A separately scheduled worker performs bounded observation.
python -m deixic.examples.account_brief resume briefs/crm-event-001.json --progress
```

The corresponding installed TypeScript commands are:

```sh
npx --no-install deixic-account-brief start briefs/crm-event-001.json \
  --account 'Example account' --trigger crm-event-001 --structured
npx --no-install deixic-account-brief resume briefs/crm-event-001.json --progress
```

Python's `--timeout` is seconds; TypeScript's is milliseconds. `--progress` writes
only matching event IDs, turn IDs and event kinds to stderr. Final JSON goes to
stdout. Deduplicate progress effects by event ID: callbacks may repeat after a
crash. The worker exits 2 for unfinished work, waiting, invalid output, failed or
unconfirmed receipts; retain its checkpoint for another scheduled observation.
Exit 1 reports configuration, storage or SDK errors. Exit 0 for a resumed task
means the matching answer passed requested validation and no returned receipt
needs attention. No receipts means `action_status: not_reported`, not a verified
external action. TypeScript JSON field names use camelCase.

This is a local application template, not a hosted queue. File writes are
private, atomically published and synced before submission. Existing task APIs
accept your own durable storage callbacks. A hosted application should use its
existing job queue and tenant-bound database/storage adapter, preserve the
same original request, and enforce one worker per checkpoint. Do not put API
credentials in checkpoints. Apply your customer-data retention policy to briefs,
checkpoint files and any abandoned temporary files after a crash.

## Validated output

`--structured` is saved in the original request; a new process automatically
validates that requested format. Plain-text requests remain supported. Parsers
are included as `deixic.examples.account_brief_result.parse_account_brief` and
`@evalops/deixic-sdk/examples/account-brief-result` (`parseAccountBrief`).

```json
{
  "schemaVersion": "deixic.account-brief.v1",
  "accountName": "Example account",
  "summary": {"text": "An active account", "sourceIds": ["account"]},
  "opportunities": [{"name": "Renewal", "stage": "Open", "sourceIds": ["opportunity"]}],
  "risks": [{"description": "Renewal has no owner", "sourceIds": ["opportunity"]}],
  "sources": [
    {"id": "account", "system": "crm", "resourceId": "account-1"},
    {"id": "opportunity", "system": "crm", "resourceId": "opportunity-1"}
  ],
  "missingData": ["Contract end date"]
}
```

The parser rejects unknown or duplicate fields, unsupported versions, invalid
types, empty facts, duplicate source IDs and dangling source references. Factual
items require a nonempty list of unique source IDs. Lists are limited to 100
items. The CLI also requires the requested account name. If CRM data is absent,
use `summary: null`, empty factual lists and an explanation in `missingData`.
Validation proves this format and reference linkage; verify actual records and
freshness through the connected source before relying on the claims.

Malformed output reports `invalid_result` with remote status `completed`. It
never starts another task or retries the model silently. Inspect the completed
answer and make any new business request explicitly.

## Explicit approval or denial

Observation can return `waiting` and the retained approval request ID. An
operator reviews the requested action in Deixic, then uses a credential with
owner-authorized decision access. The command re-fetches the current waiting
request and refuses mismatched IDs, non-approval requests or unavailable history.
Platform still authorizes the decision. A task token does not grant approval rights.

```sh
python -m deixic.examples.account_brief approve briefs/crm-event-001.json \
  --request APPROVAL_REQUEST_ID --decision-key decision-001
# Or choose deny instead of approve. TypeScript exposes the same arguments.
python -m deixic.examples.account_brief resume briefs/crm-event-001.json
```

Keep the same decision key and decision if its response is lost. A submitted
decision is not a completed task. Resume to observe the owner outcome. Missing
history stays `waiting/request_not_visible`; use Deixic's approval view. No
cached checkpoint, generated text or prompt can authorize a response.

## Completion and actions

`completed` refers to the accepted turn's linked final answer. `actions` lists
receipt IDs, owner services, object IDs, typed lifecycle states and evidence
reference IDs. `owner_reported_success` means every returned receipt is
SUCCEEDED or VERIFIED; it does not identify a particular CRM update by itself.
Confirm the relevant owner, object, action and source evidence before telling a
customer a record changed. Failed, denied, unavailable, waiting and unspecified
states require attention even when the answer completed. The account-brief
prompt requests reads only; it does not request CRM writes or sent messages.

## Recovery and release verification

| Failure | Recovery | Invariant |
| --- | --- | --- |
| Worker killed after acceptance | Resume from its checkpoint | Same accepted turn and linked answer; one submission |
| Submission accepted but response lost | Resume reports unacknowledged; explicitly replay | Original tenant, request bytes and key; one owner operation |
| Observation disconnects | Bounded read reconnect | No mutation replay |
| Storage fails before submission | Repair storage before explicit submission | No network mutation |
| Storage fails after acceptance | Preserve checkpoint; explicitly replay if unacknowledged | No automatic replay; same owner operation |
| Switch Python/TypeScript worker | Resume the same file | Decimal-string cursors and matching result |
| Approval history unavailable | Owner review in Deixic | No invented approval |

These cases run over binary HTTP with separate client processes in component CI,
including a SIGKILLed worker and storage failures. Controlled fixtures prove
SDK behavior. They do not establish deployed Identity, model or CRM execution.

```sh
# Empty consumers resolving freshly built wheels/tarball and all dependencies:
python sdk/deixic/verify_consumer.py
# The same matrix resolving exact releases from public registries:
python sdk/deixic/verify_consumer.py --python-version VERSION --typescript-version VERSION
```

The existing `deixic.examples.verify_test_journey` probe separately verifies real
Identity and Platform against an explicitly configured dedicated test tenant.
Use it after publication; never substitute a fixture receipt for live proof.
