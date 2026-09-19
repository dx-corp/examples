# Deixic examples

These are the account-brief workflows shipped with the supported Deixic SDK
packages. Each workflow creates or resumes durable work, stores a local
checkpoint, handles approval requests explicitly, and can validate a structured
answer whose facts reference their source records.

## TypeScript

```sh
npm install /path/to/evalops-deixic-sdk-0.1.2.tgz
export DEIXIC_API_KEY=...
export DEIXIC_ORGANIZATION_ID=...
export DEIXIC_WORKSPACE_ID=...
node examples/account-brief.mjs check
node examples/account-brief.mjs start checkpoint.json \
  --account "Example account" --trigger crm-brief-2026-09-18 --structured
node examples/account-brief.mjs resume checkpoint.json --progress
```

## Python

```sh
python3 -m venv .venv
. .venv/bin/activate
python -m pip install /path/to/deixic_sdk-0.1.3-py3-none-any.whl
export DEIXIC_API_KEY=...
export DEIXIC_ORGANIZATION_ID=...
export DEIXIC_WORKSPACE_ID=...
python -m python.deixic_examples.account_brief check
python -m python.deixic_examples.account_brief start checkpoint.json \
  --account "Example account" --trigger crm-brief-2026-09-18 --structured
python -m python.deixic_examples.account_brief resume checkpoint.json --progress
```

`sdk-versions.json` records the exact packages these examples are tested
against. The validator builds those artifacts from the matching reviewed SDK
projections, installs each into a clean consumer, and runs the no-credential
`check` path. Supply verified package artifacts from the supported SDK release
lane. Registry publication is a separate release state and is not assumed by
these examples.

Use a stable trigger only for the same logical request. Keep checkpoints and
API keys out of source control. A completed answer does not prove that a cited
record exists; applications must resolve references through their governed
data path before taking action.

The local validator exercises both result parsers and installs both exact SDK
artifacts before running the live examples' local configuration boundary. It
does not send a Deixic request:

```sh
DEIXIC_EXAMPLES_NODE_PACKAGE=/path/to/evalops-deixic-sdk-0.1.2.tgz \
DEIXIC_EXAMPLES_PYTHON_WHEEL=/path/to/deixic_sdk-0.1.3-py3-none-any.whl \
  node scripts/distribution-validation.mjs --name examples --target .
```
