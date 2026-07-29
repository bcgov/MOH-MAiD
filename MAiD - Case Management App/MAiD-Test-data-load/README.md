# MAiD Sandbox Test Data Load

Automates the manual procedure in *"MAiD - Test Data Set and Procedure"*:
Account -> Case -> six MAiD Form objects (1632, 1633, 1634, 1641, 1645, RX-MAR),
with the `MAiD Prevent Duplicate Phn` Flow deactivated for the duration.

Record IDs are **never reused** across orgs. Every ID in the source CSVs is
from a different org and is discarded; correct sandbox IDs are re-derived at
load time by joining on **College ID** (Accounts) and **PHN** (Cases) - the
only two values that stay meaningful across orgs.

---

## Where this sits in the repo

This tool lives as a **self-contained subfolder** and does not touch, merge
with, or depend on anything in your existing SFDX project structure:

```
MAID - CASE MANAGEMENT APP/
├── .github/
├── .sf/
├── .sfdx/
├── force-app/main/default/     ← your deployable metadata, untouched
├── manifest/                   ← your package.xml, untouched
├── scripts/                    ← your existing SFDX scripts, untouched
├── MAiD-Test-data-load/             ← this tool, self-contained
│   ├── scripts/
│   │   ├── load_test_data.py
│   │   ├── mapper.py
│   │   └── sf_runner.py
│   ├── tests/
│   ├── mapping_config.yaml
│   ├── requirements.txt
│   ├── .gitignore
│   └── README.md               ← you are here
├── package.json
└── sfdx-project.json
```

All commands below assume you've `cd`'d into `MAiD-Test-data-load/` first:
```bash
cd MAiD-Test-data-load
```

**One manual step:** append this folder's `.gitignore` rules into your
**root** `.gitignore` (don't overwrite your existing one):
```
MAiD-Test-data-load/data/*.csv
MAiD-Test-data-load/output/
MAiD-Test-data-load/**/__pycache__/
```
Nothing in `force-app`, `.forceignore`, or `manifest/package.xml` needs any
change - this tool isn't Salesforce metadata, so your existing deploy process
doesn't see it at all.

---

## Setup (once)

```bash
pip install -r requirements.txt
sf plugins install @salesforce/plugin-data   # if not already installed
```

Place your input CSVs in `MAiD-Test-data-load/data/` (gitignored - see "Why data/
and output/ aren't committed" below). **Filenames must match exactly**
(underscores, no spaces) since they're referenced directly in
`mapping_config.yaml`:
```
MAiD-Test-data-load/data/Account.csv
MAiD-Test-data-load/data/Case.csv
MAiD-Test-data-load/data/Form_1632.csv
MAiD-Test-data-load/data/Form_1633.csv
MAiD-Test-data-load/data/Form_1634.csv
MAiD-Test-data-load/data/Form_1641.csv
MAiD-Test-data-load/data/Form_1645.csv
MAiD-Test-data-load/data/Form_RxMAR.csv
```
If your exported files use spaces instead (e.g. `Form 1632.csv`), rename them
to match before running `validate`/`deploy` - `validate` will list any file
it can't find under the exact name above, rather than silently failing.

---

## The 2-step process

### Step 1 - Authenticate (manual, once per person/session)
```bash
sf org login web --alias MAidQA
```
This is the one step that can't be scripted - it's an interactive login tied
to your own Salesforce credentials/MFA.

### Step 2 - Validate, then deploy (one command each)

**Validate** - read-only pre-flight check. Loads no data, changes nothing in
the org. Checks: org connectivity, CSV files/columns present, target object
& field API names exist in the org (catches typos in `mapping_config.yaml`
before they cause a failed load), and join-key coverage (how many rows would
actually match, so you know about orphaned PHNs/College IDs up front).

```bash
python scripts/load_test_data.py validate --org MAidQA
```

**Deploy** - the real load. Deactivates the Flow, inserts Account -> exports
-> maps+inserts Case -> exports -> maps+inserts all 6 Forms, then reactivates
the Flow (guaranteed via try/finally, even if a step fails partway).

```bash
python scripts/load_test_data.py deploy --org MAidQA
```
`OwnerId` is never set explicitly - it's dropped from every object's data
before insert (even where the source CSV carries one), so Salesforce
defaults each new record's owner to whichever user is running the load.

That's it - one login, then one validate, then one deploy, all from inside
`MAiD-Test-data-load/`. Anyone on the team can run this from the doc without
needing to know the internals.

---

## Partial failures (e.g. 90 succeeded / 10 failed)

Salesforce's Bulk API already processes every row independently - a bad row
doesn't block the other 99. `deploy` surfaces this directly:

```
FINAL SUMMARY
  Account           42 succeeded  /   0 failed
  Case              36 succeeded  /   0 failed
  Form_1632         36 succeeded  /   0 failed
  Form_1633         28 succeeded  /   0 failed
  ...
```

Failed rows, with Salesforce's actual per-row error message, land in
`output/<jobid>-failed-records.csv`. Fix the underlying rows in your **own**
copy of the CSV (the original `data/*.csv` is never modified by this script)
and re-run `deploy` - or re-run just the failed subset if you've split it out.

---

## Why `data/` and `output/` aren't committed to git

- `data/*.csv` - your input files stay local (or wherever your team already
  stores them). This isn't just tidiness: these files contain patient-like
  names/DOBs/PHNs, and even in a sandbox/test context that shouldn't sit in
  git history.
- `output/` - every mapped CSV and success/failure report is regenerated on
  each run and contains the same sensitive fields, plus it's inherently
  run-specific (tied to whichever org/session produced it) - not something
  that belongs in version control.

What **is** committed: `scripts/`, `mapping_config.yaml`, `tests/`, this
README, `.gitignore`, `requirements.txt` - the reusable logic only, never data
or run output.

---

## Testing before opening a PR

1. **Unit tests (no org needed at all)** - run this first, every time, before
   touching any org:
   ```bash
   pytest tests/ -v
   ```
   These run against real (trimmed) sample data in `tests/fixtures/` and
   prove the join/ID-replacement logic is correct, entirely offline.

2. **`validate` against a real sandbox** - confirms connectivity, object/field
   API names, and join coverage without loading anything:
   ```bash
   python scripts/load_test_data.py validate --org MAidQA
   ```

3. **Small smoke test** - before running your full dataset, try `deploy`
   against a throwaway scratch org or a copy of just 3-5 rows per file, and
   manually check the resulting records in the Salesforce UI. This is the one
   step to never skip - it's the only check that confirms the actual org
   behaved as expected, not just the script logic.

### Ask Claude Code to verify this for you

If you want Claude Code to run and sanity-check this before you open a PR,
a good prompt is:

> In the `MAiD-Test-data-load/` folder, run `pytest tests/ -v` and summarize any
> failures. Then run `python scripts/load_test_data.py validate --org MAidQA`
> and tell me if anything looks wrong - especially any "target_column does
> not exist on sobject" errors, since those usually mean
> `mapping_config.yaml`'s object or field API names don't match this org.
> Don't run `deploy` unless I explicitly ask you to.

---

## Relationship to your existing metadata deploy validation

`sf project deploy validate --target-org MAidQA -x ./manifest/package.xml`
validates **metadata** (Apex, objects, flows, layouts) and is completely
unaffected by this - this script only touches **data** via the Bulk API,
a different API entirely. The one overlap: the Flow deactivate/reactivate
step in `deploy` is itself a metadata deploy. Avoid running your metadata
`deploy validate`/deploy and this script's `deploy` at the exact same moment
against the same org; running them at different times (even minutes apart)
is fine. `deploy` always restores the Flow to active before it exits (even on
failure), so by the time any other deploy runs, the Flow is back to whatever
source control says it should be.

---

## Object API names

`mapping_config.yaml`'s `sobject:` values for the six Form objects
(`Form_1632__c`, `Form_1633__c`, `Form_1634__c`, `Form_1641__c`,
`Form_1645__c`, `Form_RXMAR__c`) have been confirmed to match your org's
actual API names - no changes needed. `validate` will still catch it
immediately if this ever drifts (e.g. an object gets renamed later), so it's
worth running before every `deploy`, not just the first one.
