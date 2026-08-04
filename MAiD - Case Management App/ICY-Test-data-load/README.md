# ICY Sandbox Test Data Load

Automates the manual procedure in *"ICY Test Data Seeding Procedure"*:
Users -> Case Contact -> Account -> Referral -> Intake -> Case -> Case
Member -> 5 child objects (YTS Transition Plan, YTS Have And Needs, YTS
Goal Steps, Contribution, Notes, Document) -> 3 "Update" back-fill passes.

Unlike the MAiD tool (which hardcodes each of its 6 objects directly in
Python), this is a **generic, config-driven engine**: `mapping_config.yaml`
defines an ordered list of "stages", and `load_test_data.py` executes
whichever stage type each one declares. Adding or changing an object means
editing the YAML, not the Python - this scales much better across ICY's ~13
objects and circular dependencies than hardcoding each one would.

---

## ⚠️ Manual input required before your first real `deploy`

`validate` will refuse to pass cleanly until these are filled in - they are
genuine ambiguities the source CSVs don't resolve on their own, not
placeholders I forgot to fill in.

### 1. RecordType columns with no name available (3 objects)

`Referral` and `Case` use the special `RecordType:RecordType-Name` Data
Loader syntax with a real, readable name (e.g. `"General Referral"`) - these
resolve automatically. **`Account`, `Case_Contact`, and `Intake` only have a
plain `RecordTypeId`/`RECORDTYPEID` column holding a raw OLD-org Id with no
name attached** - there is no way to derive the correct NEW-org RecordTypeId
from a bare Id alone. In `mapping_config.yaml`, find the three
`record_type_static_overrides` blocks (on the `Account`, `Case_Contact`, and
`Intake` stages) and fill in `developer_name` with the correct Record
Type's Developer Name for each (Setup > Object Manager > *Object* > Record
Types). The script resolves the rest automatically once that's filled in.

### 2. OwnerId needing a specific "valid ICY User" (2 objects)

The source procedure says OwnerId must be *"a valid ICY User"* for `Case`
and `Case_Member` (unlike Contribution/Notes/Document, which explicitly
say to leave OwnerId blank - those already work correctly via
[Salesforce's default-to-running-user behavior](https://help.salesforce.com/s/articleView?id=000387292)
and need no change). Find the `set_fields` blocks on the `Case` and
`Case_Member` stages and fill in the actual User Id.

### 3. Object API names - best-guess, not independently confirmed

Every custom object's `sobject:` value in `mapping_config.yaml` is inferred
from CSV filenames and your screenshots (e.g. `Referral__c`, `Intake__c`,
`ICY_Case_Member__c`, `YTS_Transition_Plan__c`) - **not confirmed against a
live org** the way MAiD's eventually were. Expect `validate` to catch a
typo or two on the first run, same as MAiD's `Form_RXMAR__c` situation -
that's exactly what it's there to do.

### 4. Duplicate file: `ICY_Account.csv` vs `ICY_Acount.csv`

These two uploaded files have identical headers and row counts - likely the
same export uploaded twice under a typo'd name. Config currently points at
`ICY_Account.csv`; confirm that's the right one (or that they're genuinely
different exports) before running `deploy`.

### 5. Account, Case, and YTS_Transition_Plan need ONE manual step each

Unlike the other 13 objects (fully automated), these three have `type:
manual_insert` in `mapping_config.yaml` - `deploy` prepares the CSV for you
(Record Type resolved, dates fixed, non-createable columns dropped) and
writes it to `output/`, but **you upload it yourself** via Data
Loader/Inspector (exactly like the original procedure), then save the
success report's `Old_ID`/`ID` columns as the file named in that stage's
`reference_file`. Re-run the exact same `deploy` command afterward and it
picks up automatically - nothing before that point gets re-run or
re-touched. See "Why these three specifically" below for the full reason,
and `mapping_config.yaml`'s top-of-file comment for how to switch to a
fully-automated Composite API approach later, if wanted.

### 6. Manual, not automated (by design)

- **Email Deliverability** (Setup > Deliverability > Access level = All
  Email) - a one-time org config check. `deploy` enforces this with a hard
  gate (`--deliverability-confirmed`, see Usage below) since Salesforce
  exposes no API to verify the setting itself.
- **Deciding which users to keep active** during the deactivation step -
  a business judgment call, not a mechanical transform. `scripts/
  deactivate_users.py` automates the *execution* (see "Freeing User
  licenses" above), but the exempt list itself is a fixed decision baked
  into that script, not something it derives on its own.
- **Permission Set Group assignment** - the source procedure does this via
  Setup UI clicks; it's not included in this script's stages. It *could* be
  automated (inserting `PermissionSetAssignment` records directly) as a
  follow-up if useful.

---

## Why Account, Case, and YTS_Transition_Plan specifically need a manual step

Every "OLD_ID -> new Id" reference table this tool builds needs some real,
queryable field on the inserted record to look up afterward - MAiD's
Account/Case have genuine business-key fields for this (College ID, PHN).
Most ICY objects don't, but do have a **spare, entirely-blank custom field**
(`OLDNAME__C`, confirmed 100% blank in the real data) safe to repurpose for
this bookkeeping - that's what `bookkeeping_field` does for Case_Contact,
Referral, Intake, and Have_And_Needs, giving those 4 (plus Users) full
automation with resume/idempotency, same as MAiD.

Account, Case, and YTS_Transition_Plan have **no such spare field** -
checked directly against the real data; their only blank columns are
non-createable system fields or legitimate blank business fields (e.g.
Case's `ClosedDate`, which is blank only because these test cases aren't
closed - not safe to repurpose).

Three ways to resolve this were considered:
1. **Add a small custom field** (e.g. `Migration_Old_Id__c`) to these 3
   objects, purely for this migration - simplest to automate, but requires
   a schema change.
2. **Keep these 3 steps manual**, matching the original procedure exactly
   (chosen approach - see `type: manual_insert` above) - no schema change,
   no new automation code, at the cost of 3 manual touchpoints instead of 0.
3. **Composite/SObject Tree API** - Salesforce's Composite API lets you tag
   each record with a client-supplied `referenceId` that's echoed back with
   the new Id, achieving full automation without any schema change *or*
   manual step. Not implemented yet - it uses a different API family than
   the Bulk API used everywhere else, with a much lower per-call record
   limit (~200), so larger objects need batching logic. A solid future
   upgrade for just these 3 stages if/when zero manual touchpoints becomes
   worth the extra engineering - nothing else in the pipeline would need to
   change to adopt it.

---

## Setup

```bash
pip install -r requirements.txt
```

Place your CSVs in `data/` using the exact filenames referenced in
`mapping_config.yaml`'s `input_csv` values (run `validate` to see if any
don't match).

---

## Usage

```
Step 5 — Authenticate:
    sf org login web --alias <org>

Step 6 — Free up User licenses (one-time per org - see "Freeing User
licenses" below):
    python scripts/deactivate_users.py --org <org>              # dry run
    python scripts/deactivate_users.py --org <org> --confirm    # actually deactivates

Step 7 — Validate (read-only, loads nothing):
    python scripts/load_test_data.py validate --org <org>

Step 8 — Deploy:
    python scripts/load_test_data.py deploy --org <org> --deliverability-confirmed
```

`validate` checks org connectivity, every stage's CSV/column presence,
unresolved manual TODOs (see above), and target org field/object names.
`deploy` runs all 16 stages in order, matching MAiD's Flow-check behavior:
if `flow_api_name` is set and that Flow is active, it halts immediately
before touching any data (same exact message wording as MAiD). ICY doesn't
appear to have an equivalent duplicate-prevention Flow - `flow_api_name` is
currently `null`; fill it in if one exists.

`deploy` also refuses to run at all without `--deliverability-confirmed`.
Salesforce has no API to read Setup > Deliverability > Access to Send Email,
so this can't be checked automatically like the Flow status above - the flag
is your explicit confirmation that you checked it by hand
(Setup > Deliverability > Access level = "All Email") before running a real
load. Omitting it halts immediately with instructions, same as every other
guard in this tool - nothing gets touched.

### Freeing User licenses (Step 6)

The Users stage upserts ~298 ICY test personas, most needing a standard
`Salesforce`-license seat - if the org's existing active-user count already
consumes most of that license pool, the upsert fails with
`LICENSE_LIMIT_EXCEEDED`. `scripts/deactivate_users.py` automates the source
PDF's own Steps 1-2 (export Active Users, deactivate all but a handful) to
free up capacity, and is portable across orgs on purpose - nothing in it is
a hardcoded Id:

- The admin user is resolved fresh per org the same way `mapping_config.yaml`
  resolves `OwnerId` (`Username LIKE 'admin.user@%' AND UserRole.Name LIKE
  '%ICY%'`).
- 3 named individuals from the source PDF's exempt list are resolved by
  their GUID username prefix, which stays identical across sandbox refreshes
  of this org (only the domain suffix, e.g. `.sosehfdv` vs `.soseuat`,
  changes) - so the same command works unchanged against any sandbox derived
  from this org.
- Each exempt pattern must resolve to **exactly one** user, or the script
  refuses to run rather than risk deactivating (or failing to exempt) the
  wrong real person.

It's a **one-time-per-org** step, not part of the repeatable validate/deploy
loop - re-run it only when pointing at a brand-new sandbox for the first
time, after a sandbox refresh resets user state, or if licenses run out
again later. Always writes an audit report
(`output/deactivate_users_<org>_report.csv`) with every user's old/new
`IsActive` state, so the change can be reviewed or manually reversed later
if business disagrees with who was kept active.

**Chunking note**: this org's `UserPermissionsTrigger` isn't bulk-safe - it
loops per-record instead of using bulk DML/SOQL, and trips two separate
governor limits depending on batch size (`Too many DML statements` around
200 records/transaction, `Too many SOQL queries` around 100/transaction,
since it does ~2 non-bulkified queries per record). The script uploads in
chunks of 25 to stay well clear of both; if a future org's equivalent
trigger is even less bulk-safe, lower `CHUNK_SIZE` in the script further.

---

## Engine architecture: stage types

- **`upsert_users`**: upserts to `User` via `upsert_external_id` (Username).
- **`insert`**: loads a CSV, applies `rename_columns` / `drop_columns` /
  `special_lookups` / `lookups` / `set_fields` / `record_type_static_overrides`,
  inserts, and optionally exports a reference table (`export_as`) mapping
  `OLD_ID -> new Id` for later stages to join against - via `bookkeeping_field`,
  a real org field the OLD_ID gets written into before insert (see "Why
  Account, Case, and YTS_Transition_Plan..." above for why this needs a
  real field at all).
- **`manual_insert`**: same prep as `insert`, but instead of calling the
  Bulk API, writes the prepared CSV to `output/` and waits for a human to
  upload it and save the resulting `Old_ID`/`ID` reference file
  (`reference_file` in config). `deploy` halts with exact instructions the
  first time it reaches one of these without that file present, and picks
  it up automatically on the next run - used for `Account`, `Case`, and
  `YTS_Transition_Plan`, which have no safe field for automatic
  `bookkeeping_field`-based export.
- **`update`**: same prep as insert, but rows are matched against an
  **already-inserted** record of the same object (via `match_against_reference`
  + `match_key_column`) and updated rather than inserted. This is how the
  circular Case Contact/Referral/Intake <-> Case dependency resolves: those
  three get inserted first WITHOUT their Case links (Case doesn't exist
  yet), then a later `_Update` stage goes back and fills them in.

Two lookup mechanisms, both reusing the same underlying join logic:
- **`special_lookups`**: for Data-Loader-only "X:Name" style columns
  (RecordType, Owner, Profile, UserRole) - queries the org fresh each time
  and resolves by matching name.
- **`lookups`**: for joins against a previously-exported reference table
  from an earlier stage (the OLD_ID -> new-Id pattern, same mechanism as
  MAiD's PHN__c/College_ID__c joins).

**Important technical note on updates**: there is no `sf data update bulk`
command in current Salesforce CLI versions (confirmed absent from the
official CLI reference) - `bulk_update()` in `sf_runner.py` actually calls
`sf data upsert bulk --external-id Id`, using Salesforce's own standard Id
field as the match key. This is the documented way to do a plain update via
Bulk API 2.0, not a workaround.

---

## Real data quirks this config accounts for

- **`ICY_CaseMember.csv`'s own identity column is `OD_ID`** (typo, missing
  the "L"), not `OLD_ID` like every other object - `export_key_field` on
  that stage reflects this.
- **`ICY_Intake.csv`'s identity column is `ID`**, not `OLD_ID` - same
  reason, handled via a per-stage configurable `export_key_field` rather
  than a hardcoded assumption.
- **Non-UTF-8 encoded CSVs**: `ICY_Test_Users.csv` (and others) contain
  bytes that aren't valid UTF-8 (an accented character, likely from a
  Windows export). `mapper.load_csv()` now tries UTF-8, falls back to
  cp1252, then falls back to UTF-8 with invalid bytes replaced rather than
  crashing - this fix has also been backported to the MAiD tool.
- **Intake's `CASE__C`** is intentionally left alone during Intake's own
  insert (Case doesn't exist yet) and correctly resolved later by
  `Intake_Update` - this was initially unclear from the source procedure
  (which never explicitly mentions it during Intake prep) but the later
  Update step confirms this is the intended pattern, matching Case
  Contact/Referral's identical treatment.

---

## Testing

```bash
pytest tests/ -v
```

8 tests, all running offline against real (trimmed) samples of your actual
uploaded CSVs - no org needed. These focus on what's new/different from
MAiD's already-proven test suite: `rename_columns`, the typo'd/inconsistent
key-column names, the raw-Id-vs-name RecordType distinction, and the
already-populated-but-stale cross-org Id columns in `Case.csv`.

I also ran a full 16-stage simulation of `deploy` against your complete
real dataset (5,971 total rows across all objects) with mocked org
responses, confirming the engine executes every stage in the correct order,
correctly builds and passes reference tables between stages, and correctly
surfaces (rather than silently drops) every unresolved lookup.
