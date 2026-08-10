#!/usr/bin/env python3
"""
load_test_data.py (ICY)

Generic, config-driven version of the MAiD data-load script. Where MAiD's
script hardcoded each of its 6 objects directly in Python, ICY's chain is
~13 objects long with circular dependencies (Case Contact/Referral/Intake
get inserted WITHOUT their Case links first, then updated afterward once
Case exists) - so this reads an ordered list of "stages" from
mapping_config.yaml and executes whichever stage type each one declares.
Adding/changing an object means editing the YAML, not the Python.

  STEP 0 (manual): Verify Email Deliverability (Setup > Deliverability >
    Access level = 'All Email'). Salesforce exposes no API to read this
    setting, so `deploy` can't check it for you - it refuses to run at all
    unless you pass --deliverability-confirmed as proof you checked it.
  STEP 1 (manual): sf org login web --alias <org>
  STEP 2 (this script):
    python scripts/load_test_data.py validate --org <org>
    python scripts/load_test_data.py deploy   --org <org> --deliverability-confirmed

`validate` never writes to the org - read-only pre-flight check.
`deploy` runs every stage in the order defined in mapping_config.yaml.

Stage types:
  - upsert_users: upsert to User via an external-id-style matching field
    (Username), with special_lookups for Profile/UserRole-style resolution.
  - insert: load a CSV, apply rename_columns / special_lookups / lookups /
    set_fields, insert, and optionally export a reference table (OLD_ID ->
    new Id) for later stages to join against, via a repurposed
    bookkeeping_field.
  - manual_insert: same prep as insert, but instead of calling the Bulk
    API, writes the prepared CSV to output/ and waits for a human to
    upload it via Data Loader/Inspector and save the resulting Old_ID/ID
    reference file (see `reference_file` in mapping_config.yaml). Used for
    Account, Case, and YTS_Transition_Plan, which have no safe field to
    build an automatic reference table from - see mapping_config.yaml's
    top-of-file comment for the full explanation. `deploy` halts with
    clear instructions the first time it reaches one of these without the
    reference file present, and picks it up automatically on the next run.
  - update: same prep as insert, but the CSV rows are matched to
    ALREADY-inserted records of the same object (via that object's own
    reference table) and updated rather than inserted - this is how the
    circular Case Contact/Referral/Intake <-> Case dependency resolves.

HOW REFERENCE TABLES ACTUALLY WORK (see mapping_config.yaml's top-of-file
comment for the full story): a stage's `export_key_field` names the CSV
column holding this object's own OLD-org identity value (e.g. OLD_ID).
That column is NEVER a real Salesforce field, so on its own it can't be
queried back after insert. `bookkeeping_field` names a real, confirmed-safe
custom field this object actually has, which gets the OLD-id value written
into it before insert - giving a genuine, queryable field to build the
reference table from afterward. If a stage needs `export_as` but has no
working `bookkeeping_field`, `deploy` refuses to start at all (see
_check_blocked_stages) rather than run partway and fail confusingly later.

Original CSVs under data/ are never modified. All derived/mapped CSVs and
reference tables are written to output/, which is .gitignored.
"""
from __future__ import annotations
import argparse
import json
import os
import sys
import yaml
import pandas as pd

sys.path.insert(0, os.path.dirname(__file__))
import mapper
import sf_runner

CONFIG_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), "mapping_config.yaml")
OUTPUT_DIR = "output"

# Same governor-limit workaround as deactivate_users.py's CHUNK_SIZE (see its
# comment for the exact "Too many DML statements"/"Too many SOQL queries"
# numbers this org's non-bulk-safe UserPermissionsTrigger trips at) - a
# single unchunked Users upsert hits the identical limit, since Bulk API 2.0
# gives callers no control over its own internal batch size.
USER_UPSERT_CHUNK_SIZE = 25


def load_config() -> dict:
    with open(CONFIG_PATH) as f:
        return yaml.safe_load(f)


# --------------------------------------------------------------------------
# Shared helpers
# --------------------------------------------------------------------------
def _resolve_special_lookups(org_alias: str, df, special_lookups: list, stage_name: str):
    """Handles the 'Data-Loader-only special mapping' columns: RecordType:Name,
    Owner:Name, Profile:Name, UserRole:Name, etc. Queries the org fresh for
    each one and resolves via mapper.apply_lookups (which also drops the
    helper column when drop_source is set)."""
    lookups_for_apply = []
    lookup_maps = {}
    for i, sl in enumerate(special_lookups or []):
        map_name = f"special_{i}"
        query = f"SELECT Id, {sl['match_field']} FROM {sl['query_sobject']}"
        records = sf_runner.query(org_alias, query)
        m = {}
        for r in records:
            key = r.get(sl["match_field"])
            if key:
                m.setdefault(key, r["Id"])
        lookup_maps[map_name] = m
        lookups_for_apply.append({
            "source_column": sl["source_column"],
            "target_column": sl["target_column"],
            "map": map_name,
            "drop_source": sl.get("drop_source", True),
        })
        print(f"  [{stage_name}] resolved {len(m)} {sl['query_sobject']} record(s) "
              f"for {sl['source_column']} -> {sl['target_column']}")

    if not lookups_for_apply:
        return df, []
    result = mapper.apply_lookups(df, lookups_for_apply, lookup_maps)
    return result.dataframe, result.unmatched_rows


def _resolve_reference_lookups(df, lookups: list, reference_tables: dict, stage_name: str):
    """Resolves lookups against previously-exported reference tables (the
    OLD_ID -> new Id maps built by earlier stages)."""
    if not lookups:
        return df, []
    lookups_for_apply = []
    lookup_maps = {}
    for lk in lookups:
        ref_name = lk["reference"]
        if ref_name not in reference_tables:
            raise KeyError(
                f"[{stage_name}] lookup references '{ref_name}', but no earlier stage "
                f"exported a reference table under that name. Check 'export_as' on the "
                f"stage that should produce it, and stage ORDER in mapping_config.yaml."
            )
        lookups_for_apply.append({
            "source_column": lk["source_column"],
            "target_column": lk["target_column"],
            "map": ref_name,
            "drop_source": lk.get("drop_source", False),
        })
        lookup_maps[ref_name] = reference_tables[ref_name]
    result = mapper.apply_lookups(df, lookups_for_apply, lookup_maps)
    return result.dataframe, result.unmatched_rows


def _print_unmatched(stage_name: str, unmatched: list):
    if unmatched:
        print(f"  WARNING [{stage_name}]: {len(unmatched)} row(s) had an unresolved lookup "
              f"(blanked out, not dropped):")
        for u in unmatched[:10]:
            print(f"    row {u['row_index']}: {u['source_column']}='{u['source_value']}' "
                  f"-> {u['target_column']} ({u['reason']})")
        if len(unmatched) > 10:
            print(f"    ... and {len(unmatched) - 10} more")


def _resolve_sandbox_suffix(org_alias: str) -> str:
    """Derives this org's real sandbox-name suffix (e.g. 'sosehfdv') from an
    actual existing username, rather than trusting the --org CLI alias -
    the alias is just a local nickname chosen at login time and is NOT
    guaranteed to match Salesforce's real internal sandbox name (confirmed
    in practice: alias 'SOSEHFDEV' vs real suffix 'sosehfdv' - close but not
    identical). Used by ensure_username_domain_suffix so every Username ends
    up unique to this org, not a look-alike string that would just create a
    different, still-wrong duplicate."""
    records = sf_runner.query(
        org_alias,
        "SELECT Username FROM User WHERE Username LIKE 'admin.user@%' AND UserRole.Name LIKE '%ICY%'"
    )
    if len(records) != 1:
        raise ValueError(
            f"Could not uniquely resolve the admin user's Username in org '{org_alias}' "
            f"(matched {len(records)} record(s)) - needed to derive the real sandbox suffix "
            f"for ensure_username_domain_suffix."
        )
    username = records[0]["Username"]
    if "." not in username:
        raise ValueError(f"Admin username '{username}' has no '.' suffix to derive a sandbox name from.")
    return username.rsplit(".", 1)[1]


def _blocked_stages(cfg: dict) -> list[dict]:
    """Automated insert stages that need a reference table (export_as) but
    have no working bookkeeping_field to build one from. `manual_insert`
    stages are exempt - they're expected to have export_as without a
    bookkeeping_field by design (they use reference_file instead)."""
    return [s for s in cfg["stages"]
            if s.get("type") == "insert" and s.get("export_as") and not s.get("bookkeeping_field")]


def _format_result_paths(job) -> str:
    if job.job_id is None:
        return "(no job run - see skip note above)"
    if job.success_records_path or job.failed_records_path:
        return f"(details: {job.success_records_path}, {job.failed_records_path})"
    return (f"(run 'sf data import resume --job-id {job.job_id} --target-org <org>' "
            f"for full per-row results if needed - counts above are already reliable)")


def _skip_result(existing_records: list[dict]) -> sf_runner.BulkJobResult:
    """A stand-in BulkJobResult for a stage whose rows were found to already
    exist in the org - job_id is left None, which is what the summary and
    _format_result_paths() use to recognize a skipped (not actually run)
    step rather than a completed bulk job."""
    n = len(existing_records)
    return sf_runner.BulkJobResult(None, n, n, 0, None, None)


def _partition_by_existing(df: pd.DataFrame, key_column: str, existing_keys: set) -> tuple[pd.DataFrame, int]:
    """Splits df's rows into (rows still needing insert, count already in the
    org). This is what makes a re-run after a partial failure safe: only
    rows not already present get re-inserted, instead of creating
    duplicates or skipping rows that never actually made it in."""
    already_here = df[key_column].isin(existing_keys)
    return df[~already_here].reset_index(drop=True), int(already_here.sum())


# --------------------------------------------------------------------------
# VALIDATE
# --------------------------------------------------------------------------
def run_validate(org_alias: str) -> int:
    cfg = load_config()
    problems = []

    print(f"== Checking org connection: {org_alias} ==")
    try:
        org_info = sf_runner.check_org_connection(org_alias)
        print(f"  OK - connected as {org_info.get('username', '?')}")
    except Exception as e:
        problems.append(f"Cannot connect to org '{org_alias}': {e}")
        print(f"  FAILED: {e}")

    print("\n== Checking for stages with no working reference-table mechanism ==")
    blocked = _blocked_stages(cfg)
    if blocked:
        for s in blocked:
            problems.append(
                f"[{s['name']}] needs export_as='{s['export_as']}' but has no bookkeeping_field - "
                f"see the CRITICAL FINDING comment at the top of mapping_config.yaml for what this "
                f"means and how to resolve it"
            )
    else:
        print("  OK - every stage needing a reference table has a working bookkeeping_field.")

    print("\n== Checking for unresolved manual TODOs in mapping_config.yaml ==")
    for stage in cfg["stages"]:
        for rt in stage.get("record_type_static_overrides", []):
            if not rt.get("developer_name"):
                problems.append(
                    f"[{stage['name']}] record_type_static_overrides entry for "
                    f"'{rt['target_column']}' has no developer_name set - this MUST be "
                    f"filled in manually (see README: 'RecordType columns needing manual input')"
                )
        for field, value in (stage.get("set_fields") or {}).items():
            if value == "":
                problems.append(
                    f"[{stage['name']}] set_fields['{field}'] is blank - this MUST be filled "
                    f"in manually with a real Salesforce Id before deploy"
                )

    print("\n== Checking input CSVs exist and configured columns are present ==")
    field_types_by_stage: dict[str, dict[str, dict]] = {}
    for stage in cfg["stages"]:
        path = stage.get("input_csv")
        if not path:
            continue
        if not os.path.exists(path):
            problems.append(f"[{stage['name']}] input CSV not found: {path}")
            print(f"  [{stage['name']}] MISSING FILE: {path}")
            continue
        df = mapper.load_csv(path)
        print(f"  [{stage['name']}] {path} - {len(df)} rows, {len(df.columns)} columns")

        rename_map = stage.get("rename_columns", {})
        effective_cols = {rename_map.get(c, c) for c in df.columns}

        for sl in stage.get("special_lookups", []):
            if sl["source_column"] not in df.columns and sl["source_column"] not in effective_cols:
                problems.append(f"[{stage['name']}] special_lookup source_column "
                                 f"'{sl['source_column']}' not found in {path}")
        for lk in stage.get("lookups", []):
            if lk["source_column"] not in df.columns and lk["source_column"] not in effective_cols:
                problems.append(f"[{stage['name']}] lookup source_column "
                                 f"'{lk['source_column']}' not found in {path}")

        for col in df.columns:
            renamed = rename_map.get(col, col)
            handled = ({sl["source_column"] for sl in stage.get("special_lookups", [])}
                       | {lk["source_column"] for lk in stage.get("lookups", [])}
                       | set(stage.get("drop_columns", [])))
            if " " in renamed and col not in handled:
                problems.append(
                    f"[{stage['name']}] column '{renamed}' contains a space - Salesforce API "
                    f"field names never do, this will break the real Bulk API load unless "
                    f"it's declared as a lookup/special_lookup source_column or drop_columns entry"
                )

    print("\n== Checking export_key_field (bookkeeping/resume key) for blank values ==")
    any_key_checked = False
    for stage in cfg["stages"]:
        ekf = stage.get("export_key_field")
        path = stage.get("input_csv")
        if not ekf or not path or not os.path.exists(path):
            continue
        any_key_checked = True
        df = mapper.load_csv(path)
        if ekf not in df.columns:
            continue  # already reported as a missing-column problem above
        blank_n = int((df[ekf] == "").sum())
        if not blank_n:
            continue
        if ekf in stage.get("drop_rows_if_blank", []):
            print(f"  [{stage['name']}] {blank_n} row(s) with blank '{ekf}' - "
                  f"already covered by drop_rows_if_blank, safe")
        else:
            problems.append(
                f"[{stage['name']}] {blank_n} row(s) have a blank export_key_field "
                f"('{ekf}') - the resume-check query deliberately excludes blank "
                f"keys, so these rows can NEVER be recognized as already-inserted "
                f"on a re-run, and `deploy` would silently create a new duplicate "
                f"record for them every single time. Add '{ekf}' to this stage's "
                f"drop_rows_if_blank to skip them safely, or fix the source data "
                f"if they shouldn't be blank."
            )
            print(f"  [{stage['name']}] {blank_n} row(s) with blank '{ekf}' - "
                  f"NOT covered by drop_rows_if_blank, WILL duplicate on every re-run")
    if not any_key_checked:
        print("  (no stages use export_key_field)")

    print("\n== Checking target org field/object names (catches typos in mapping_config.yaml) ==")
    if not problems or all("Cannot connect" not in p for p in problems):
        for stage in cfg["stages"]:
            sobject = stage.get("sobject")
            if not sobject:
                continue
            try:
                fields = sf_runner.describe_sobject_fields(org_alias, sobject)
            except Exception as e:
                problems.append(f"[{stage['name']}] could not describe sobject '{sobject}': {e}")
                continue
            field_types_by_stage[stage["name"]] = fields
            for lk in stage.get("lookups", []) + stage.get("special_lookups", []):
                if lk["target_column"] not in fields:
                    problems.append(
                        f"[{stage['name']}] target_column '{lk['target_column']}' does not "
                        f"exist on sobject '{sobject}' in org '{org_alias}'"
                    )
            if stage.get("bookkeeping_field") and stage["bookkeeping_field"] not in fields:
                problems.append(
                    f"[{stage['name']}] bookkeeping_field '{stage['bookkeeping_field']}' does not "
                    f"exist on sobject '{sobject}' in org '{org_alias}'"
                )
            # Case-insensitive, same reasoning as drop_noncreateable_columns -
            # confirmed in practice (YTS_Have_And_Needs's OwnerId) that a
            # set_fields/set_fields_from_query target can reference a field
            # that flat-out doesn't exist on this object in this org, which
            # otherwise only surfaces as a deploy-time crash
            # ("InvalidBatch: Field name not found").
            fields_lower = {f.lower() for f in fields}
            set_field_targets = list(stage.get("set_fields") or {}) + \
                [sfq["target_column"] for sfq in stage.get("set_fields_from_query", [])]
            for target in set_field_targets:
                if target.lower() not in fields_lower:
                    problems.append(
                        f"[{stage['name']}] set_fields target '{target}' does not exist on "
                        f"sobject '{sobject}' in org '{org_alias}'"
                    )
    else:
        print("  SKIPPED - org connection failed above.")

    print("\n== Checking set_fields_from_query resolves to exactly one record in this org ==")
    if not problems or all("Cannot connect" not in p for p in problems):
        any_query = False
        for stage in cfg["stages"]:
            for sfq in stage.get("set_fields_from_query", []):
                any_query = True
                query = sfq["query"]
                try:
                    records = sf_runner.query(org_alias, query)
                except Exception as e:
                    problems.append(
                        f"[{stage['name']}] set_fields_from_query for '{sfq['target_column']}' "
                        f"failed to run: {e}"
                    )
                    continue
                if len(records) == 0:
                    problems.append(
                        f"[{stage['name']}] set_fields_from_query for '{sfq['target_column']}' "
                        f"matched no records in org '{org_alias}' - query: {query}"
                    )
                elif len(records) > 1:
                    problems.append(
                        f"[{stage['name']}] set_fields_from_query for '{sfq['target_column']}' "
                        f"matched {len(records)} records in org '{org_alias}' (ambiguous, expected "
                        f"exactly 1) - query: {query}"
                    )
                else:
                    print(f"  [{stage['name']}] '{sfq['target_column']}' resolves to "
                          f"{records[0]['Id']} in org '{org_alias}'")
        if not any_query:
            print("  (no stages use set_fields_from_query)")
    else:
        print("  SKIPPED - org connection failed above.")

    print("\n== Checking record_type_static_overrides resolves to exactly one ACTIVE RecordType ==")
    if not problems or all("Cannot connect" not in p for p in problems):
        any_rt = False
        for stage in cfg["stages"]:
            for rt in stage.get("record_type_static_overrides", []):
                dev_name = rt.get("developer_name", "").strip()
                if not dev_name:
                    continue  # already reported as a blank-TODO problem above
                any_rt = True
                sobject = stage.get("sobject")
                try:
                    records = sf_runner.query(
                        org_alias,
                        f"SELECT Id FROM RecordType WHERE SObjectType = '{sobject}' "
                        f"AND DeveloperName = '{dev_name}' AND IsActive = true"
                    )
                except Exception as e:
                    problems.append(
                        f"[{stage['name']}] record_type_static_overrides query for "
                        f"'{dev_name}' failed to run: {e}"
                    )
                    continue
                if len(records) != 1:
                    problems.append(
                        f"[{stage['name']}] found {len(records)} active RecordType(s) with "
                        f"DeveloperName '{dev_name}' on sobject '{sobject}' in org "
                        f"'{org_alias}' (expected exactly 1) - check Setup > Object Manager > "
                        f"{sobject} > Record Types for a naming collision or an inactive "
                        f"duplicate (confirmed to happen in practice - Account's "
                        f"'ICY_Person_Account' has both an active and inactive RecordType "
                        f"sharing the same DeveloperName)."
                    )
                else:
                    print(f"  [{stage['name']}] '{dev_name}' resolves to {records[0]['Id']} "
                          f"in org '{org_alias}'")
        if not any_rt:
            print("  (no stages use record_type_static_overrides with a filled-in developer_name)")
    else:
        print("  SKIPPED - org connection failed above.")

    print("\n== Checking date field formats (org 'date' fields must end up YYYY-MM-DD - "
          "bare M/D/YYYY is auto-converted at deploy time, anything else fails the real load) ==")
    if not field_types_by_stage:
        print("  SKIPPED - org field types unavailable (see sobject/field check above).")
    else:
        for stage in cfg["stages"]:
            path = stage.get("input_csv")
            if not path or not os.path.exists(path):
                continue
            field_types = field_types_by_stage.get(stage["name"])
            if not field_types:
                continue
            df = mapper.load_csv(path)
            date_columns = [c for c in df.columns if field_types.get(c, {}).get("type") == "date"]
            for col in date_columns:
                convertible, unrecognized = mapper.analyze_date_column(df[col])
                if unrecognized:
                    sample = ", ".join(repr(v) for v in unrecognized[:5])
                    problems.append(
                        f"[{stage['name']}] column '{col}' has {len(unrecognized)} value(s) "
                        f"that are neither YYYY-MM-DD nor M/D/YYYY, e.g. {sample} - these rows "
                        f"will fail the real Bulk API load"
                    )
                elif convertible:
                    print(f"  [{stage['name']}] column '{col}': {convertible} value(s) will be "
                          f"auto-converted from M/D/YYYY to YYYY-MM-DD at deploy time")

    print("\n== Checking for non-createable columns (formula/system/FLS-restricted fields the "
          "Bulk API would reject - these are dropped automatically at deploy time) ==")
    if not field_types_by_stage:
        print("  SKIPPED - org field types unavailable (see sobject/field check above).")
    else:
        for stage in cfg["stages"]:
            path = stage.get("input_csv")
            if not path or not os.path.exists(path):
                continue
            field_types = field_types_by_stage.get(stage["name"])
            if not field_types:
                continue
            df = mapper.load_csv(path)
            if stage.get("rename_columns"):
                df = mapper.rename_columns(df, stage["rename_columns"])
            protect = {c for c in (stage.get("export_key_field"), stage.get("match_key_column")) if c}
            flag = "updateable" if stage.get("type") == "update" else "createable"
            _, dropped = mapper.drop_noncreateable_columns(df, field_types, protect_columns=protect, flag=flag)
            if dropped:
                print(f"  [{stage['name']}] {len(dropped)} column(s) will be dropped before "
                      f"insert (not {flag} in this org): {', '.join(sorted(dropped))}")

    print("\n" + "=" * 60)
    if problems:
        print(f"VALIDATION FAILED - {len(problems)} problem(s) found:\n")
        for p in problems:
            print(f"  - {p}")
        result = 1
    else:
        print("VALIDATION PASSED - safe to run `deploy`.")
        print("\nOther reminders (manual, not automated):")
        print("  - Confirm which users were deactivated/exempted per the source procedure.")
        result = 0

    # Always shown, pass or fail - Salesforce has no API to check this setting
    # (see the --deliverability-confirmed gate on `deploy`), so it's easy to
    # forget precisely because nothing here can enforce it automatically.
    print("\nPlease check the following setting: Verify the Email Deliverability settings:")
    print("  Setup > Deliverability > Access level = All email")

    return result


# --------------------------------------------------------------------------
# DEPLOY
# --------------------------------------------------------------------------
def run_deploy(org_alias: str, deliverability_confirmed: bool) -> int:
    if not deliverability_confirmed:
        print("DEPLOY HALTED - Email Deliverability has not been confirmed (nothing has")
        print("been touched).\n")
        print("Salesforce provides no API to read Setup > Deliverability > Access to Send")
        print("Email, so this can't be checked automatically - it must be confirmed by hand")
        print("once per org before the first deploy:")
        print("  Setup > Deliverability > Access level = 'All Email'\n")
        print("Once confirmed, re-run with --deliverability-confirmed:")
        print(f"  python scripts/load_test_data.py deploy --org {org_alias} --deliverability-confirmed")
        return 1

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    cfg = load_config()

    blocked = _blocked_stages(cfg)
    if blocked:
        print("DEPLOY HALTED - the following stage(s) need a reference table but have no")
        print("working bookkeeping_field to build one from (nothing has been touched):\n")
        for s in blocked:
            print(f"  - {s['name']} (needs export_as='{s['export_as']}')")
        print("\nSee the CRITICAL FINDING comment at the top of mapping_config.yaml for what")
        print("this means and how to resolve it (adding a small custom field is recommended).")
        return 1

    flow_name = cfg.get("flow_api_name")
    if flow_name:
        print(f"== Checking Flow status: {flow_name} ==")
        active_version_id = sf_runner.get_active_flow_version_id(org_alias, flow_name)
        if active_version_id:
            print(f"\nThe flow: {flow_name} is active and it prevents the dataload. "
                  f"To begin the data load please de-activate this flow and once all the "
                  f"data load work is done please activate it manually.")
            return 1
        print(f"  Confirmed: Flow '{flow_name}' is deactivated. Proceeding with data load.")

    reference_tables: dict = {}
    summary = []

    for stage in cfg["stages"]:
        name = stage["name"]
        stage_type = stage["type"]
        print(f"\n== Preparing {name} ({stage_type}) ==")

        df = mapper.normalize_us_dates(mapper.load_csv(stage["input_csv"]))
        df = mapper.drop_owner_columns(df)

        if stage.get("drop_username_domains"):
            df, dropped = mapper.drop_rows_by_username_domain(df, stage["drop_username_domains"])
            if dropped:
                print(f"  [{name}] skipping {dropped} row(s) - Salesforce auto-generated "
                      f"username domain(s) {stage['drop_username_domains']}, not real test personas")

        if stage.get("ensure_username_domain_suffix"):
            sandbox_suffix = _resolve_sandbox_suffix(org_alias)
            df, changed = mapper.ensure_username_domain_suffix(df, sandbox_suffix)
            if changed:
                print(f"  [{name}] appended this org's real sandbox suffix "
                      f"'.{sandbox_suffix}' to {changed} Username(s) that didn't already end with it")

        if stage.get("rename_columns"):
            df = mapper.rename_columns(df, stage["rename_columns"])

        if stage.get("value_remap"):
            df = mapper.remap_values(df, stage["value_remap"])
            for col, value_map in stage["value_remap"].items():
                print(f"  [{name}] remapped value(s) in '{col}': {value_map}")

        if stage.get("drop_columns"):
            existing = [c for c in stage["drop_columns"] if c in df.columns]
            if existing:
                df = df.drop(columns=existing)
                print(f"  [{name}] dropped column(s) with no automatic resolution: {existing}")

        if stage.get("special_lookups"):
            df, unmatched = _resolve_special_lookups(org_alias, df, stage["special_lookups"], name)
            _print_unmatched(name, unmatched)

        for rt in stage.get("record_type_static_overrides", []):
            dev_name = rt.get("developer_name", "").strip()
            if not dev_name:
                raise ValueError(
                    f"[{name}] record_type_static_overrides for '{rt['target_column']}' has no "
                    f"developer_name set in mapping_config.yaml - this is a manual TODO that "
                    f"must be filled in before deploy (see the note at the top of that file). "
                    f"`validate` should have caught this - if you're seeing this, deploy was "
                    f"run without validate first."
                )
            records = sf_runner.query(
                org_alias, f"SELECT Id FROM RecordType WHERE SObjectType = '{stage['sobject']}' "
                           f"AND DeveloperName = '{dev_name}' AND IsActive = true"
            )
            # IsActive=true is required, not optional - confirmed in practice that this org
            # has TWO RecordType rows sharing the same DeveloperName on the same sobject (one
            # active, one inactive, e.g. Account's "ICY_Person_Account"). Without this filter,
            # the query returns both and silently uses whichever one Salesforce lists first -
            # which was the INACTIVE one here, producing a confusing
            # "Record Type ID: this ID value isn't valid for the user" error at insert time
            # that looks like a permission problem but is really just the wrong Id.
            if len(records) != 1:
                raise ValueError(
                    f"[{name}] found {len(records)} active RecordType(s) with DeveloperName "
                    f"'{dev_name}' on sobject '{stage['sobject']}' in org '{org_alias}' "
                    f"(expected exactly 1) - check Setup > Object Manager > {stage['sobject']} "
                    f"> Record Types for a naming collision or an inactive duplicate."
                )
            resolved_id = records[0]["Id"]
            df = mapper.set_static_fields(df, {rt["target_column"]: resolved_id})
            print(f"  [{name}] resolved Record Type '{dev_name}' -> {resolved_id} for {rt['target_column']}")

        if stage.get("lookups"):
            df, unmatched = _resolve_reference_lookups(df, stage["lookups"], reference_tables, name)
            _print_unmatched(name, unmatched)

        # Runs after BOTH special_lookups and lookups (not right after
        # special_lookups only) - a drop_rows_if_blank target might be
        # resolved by either mechanism (e.g. Users' ProfileId via
        # special_lookups, Case_Member's Referral__c via plain lookups),
        # and checking too early would find the column not yet populated.
        for col in stage.get("drop_rows_if_blank", []):
            if col in df.columns:
                blank_mask = df[col] == ""
                dropped_n = int(blank_mask.sum())
                if dropped_n:
                    df = df[~blank_mask].reset_index(drop=True)
                    print(f"  [{name}] skipping {dropped_n} row(s) with blank '{col}' - "
                          f"see mapping_config.yaml comment on this stage for why")

        for sfq in stage.get("set_fields_from_query", []):
            query = sfq["query"]
            records = sf_runner.query(org_alias, query)
            if len(records) != 1:
                raise ValueError(
                    f"[{name}] set_fields_from_query for '{sfq['target_column']}' matched "
                    f"{len(records)} record(s) in org '{org_alias}' (expected exactly 1) - "
                    f"query: {query}. `validate` should have caught this - if you're seeing "
                    f"this, deploy was run without validate first."
                )
            resolved_id = records[0]["Id"]
            df = mapper.set_static_fields(df, {sfq["target_column"]: resolved_id})
            print(f"  [{name}] resolved set_fields_from_query -> {resolved_id} for "
                  f"{sfq['target_column']}")

        if stage.get("set_fields"):
            for field, value in stage["set_fields"].items():
                if value == "":
                    raise ValueError(
                        f"[{name}] set_fields['{field}'] is blank in mapping_config.yaml - "
                        f"this is a manual TODO that must be filled in with a real Id before "
                        f"deploy (see the note at the top of that file)."
                    )
            df = mapper.set_static_fields(df, stage["set_fields"])

        # ---- manual_insert: no safe field exists to build a reference
        # table automatically (see mapping_config.yaml's top-of-file
        # comment) - a human uploads this one via Data Loader/Inspector and
        # saves the resulting Old_ID/ID reference file. Handled entirely
        # separately from the automated insert/upsert/update path below. ----
        if stage_type == "manual_insert":
            reference_file = stage["reference_file"]
            if os.path.exists(reference_file):
                ref_df = mapper.load_csv(reference_file)
                ref_map = mapper.build_lookup_map(ref_df, "Old_ID", id_field="ID")
                reference_tables[stage["export_as"]] = ref_map
                job = _skip_result([{"Old_ID": k} for k in ref_map])
                print(f"  [{name}] found {reference_file} - {len(ref_map)} record(s) loaded "
                      f"into reference table '{stage['export_as']}', no upload needed this run.")
                summary.append((name, job, 0, None))
                continue

            field_meta = sf_runner.describe_sobject_fields(org_alias, stage["sobject"])
            df, dropped_cols = mapper.drop_noncreateable_columns(
                df, field_meta, protect_columns={stage["export_key_field"]})
            if dropped_cols:
                print(f"  [{name}] dropping {len(dropped_cols)} non-createable column(s) "
                      f"before upload: {', '.join(sorted(dropped_cols))}")
            # export_key_field (OLD_ID) is deliberately KEPT (not dropped) here,
            # unlike automated insert stages - Data Loader/Inspector will carry
            # it through unmapped into the success report, which is exactly
            # what you'll trim down to build reference_file from.
            ready_path = f"{OUTPUT_DIR}/{name}_ready_for_manual_upload.csv"
            df.to_csv(ready_path, index=False)

            print(f"\n{'=' * 60}")
            print(f"MANUAL STEP REQUIRED: {name}")
            print(f"{'=' * 60}")
            print(f"1. Upload {ready_path} via Data Loader or Inspector (insert into {stage['sobject']}).")
            print(f"2. Open the success report, keep only two columns: Old_ID and ID.")
            print(f"3. Save it as: {reference_file}")
            print(f"4. Re-run this exact command - it will pick up from here automatically:")
            print(f"     python scripts/load_test_data.py deploy --org {org_alias} --deliverability-confirmed")
            print(f"\nNothing else has been touched - stages before this one already completed.")
            return 1

        # ---- composite_insert: same "no safe bookkeeping field" objects as
        # manual_insert above, but fully automated via the Composite/SObject
        # Tree API instead of a human Data Loader upload - see
        # sf_runner.composite_tree_insert_batch's docstring for why this
        # object family specifically makes that possible (Salesforce echoes
        # the new Id back paired with a client-supplied referenceId in the
        # SAME response, no separate query needed). ----
        if stage_type == "composite_insert":
            field_meta = sf_runner.describe_sobject_fields(org_alias, stage["sobject"])
            df, dropped_cols = mapper.drop_noncreateable_columns(
                df, field_meta, protect_columns={stage["export_key_field"]})
            if dropped_cols:
                print(f"  [{name}] dropping {len(dropped_cols)} non-createable column(s) "
                      f"before insert: {', '.join(sorted(dropped_cols))}")

            export_key_field = stage["export_key_field"]

            # Local progress file substitutes for the org-side bookkeeping
            # query the other automated insert stages use (impossible here -
            # that's the whole reason this family needed manual_insert
            # originally). Without this, re-running deploy after a partial
            # failure (e.g. batch 7 of 12 for a 2000+ row object) would
            # re-insert every already-succeeded batch as duplicates.
            progress_path = f"{OUTPUT_DIR}/{name}_composite_tree_progress.json"
            progress: dict = {}
            if os.path.exists(progress_path):
                with open(progress_path, encoding="utf-8") as f:
                    progress = json.load(f)
                print(f"  [{name}] found {progress_path} - {len(progress)} record(s) already "
                      f"inserted in a previous partial run, skipping those")
            already_had = len(progress)  # for the FINAL SUMMARY tag below - captured
            # before this run's batches add anything new to `progress`.

            pending = df[~df[export_key_field].isin(progress.keys())].reset_index(drop=True)
            records = mapper.build_composite_tree_records(pending, stage["sobject"], export_key_field)
            records = mapper.coerce_composite_tree_field_types(records, field_meta)

            BATCH_SIZE = 200  # hard Composite Tree API limit, not configurable
            total_batches = (len(records) + BATCH_SIZE - 1) // BATCH_SIZE
            total_failed = 0
            for i in range(0, len(records), BATCH_SIZE):
                batch = records[i:i + BATCH_SIZE]
                batch_num = i // BATCH_SIZE + 1
                result = sf_runner.composite_tree_insert_batch(
                    org_alias, stage["sobject"], batch, output_dir=OUTPUT_DIR
                )
                batch_succeeded, batch_failed = 0, 0
                for r in result.get("results", []):
                    if "id" in r:
                        progress[r["referenceId"]] = r["id"]
                        batch_succeeded += 1
                    else:
                        batch_failed += 1
                        print(f"  [{name}] batch {batch_num}/{total_batches} FAILED "
                              f"referenceId={r.get('referenceId')}: {r.get('errors')}")
                total_failed += batch_failed
                # Persisted after EVERY batch, not just at the end, so a
                # failure partway through a large object still leaves
                # earlier-succeeded batches safely resumable.
                with open(progress_path, "w", encoding="utf-8") as f:
                    json.dump(progress, f)
                print(f"  [{name}] batch {batch_num}/{total_batches}: "
                      f"{batch_succeeded} succeeded, {batch_failed} failed")

            total_succeeded = len(progress)
            print(f"  {total_succeeded} succeeded, {total_failed} failed "
                  f"(cumulative, includes any prior partial run)")

            job = sf_runner.BulkJobResult(
                "composite-tree", total_succeeded + total_failed, total_succeeded,
                total_failed, None, progress_path if total_failed else None,
            )
            # FINAL SUMMARY tag mirrors the plain-insert wording below, even
            # though the mechanism differs (local progress file vs org
            # query) - without this, a fully-resumed run (0 new rows sent)
            # printed the exact same line as a from-scratch first run,
            # making it look like everything had just been re-inserted.
            newly_this_run = total_succeeded - already_had
            if already_had and newly_this_run == 0 and total_failed == 0:
                tag_override = "  (already existed in org - insert skipped)"
            elif already_had:
                tag_override = (f"  ({already_had} pre-existing row(s) from a previous run, "
                                 f"not re-inserted)")
            else:
                tag_override = ""
            summary.append((name, job, 0, tag_override))

            if stage.get("export_as"):
                reference_tables[stage["export_as"]] = dict(progress)
                print(f"  [{name}] {len(progress)} record(s) available in reference table "
                      f"'{stage['export_as']}'")
            continue

        # Write this stage's own OLD-org identity value into a real,
        # confirmed-safe org field (bookkeeping_field) so it can be queried
        # back after insert - see module docstring. The raw identity column
        # itself is never a real field and is always dropped before insert.
        export_key_field = stage.get("export_key_field")
        bookkeeping_field = stage.get("bookkeeping_field")
        if export_key_field:
            if bookkeeping_field:
                df[bookkeeping_field] = df[export_key_field]
            df = df.drop(columns=[export_key_field])

        # match_key_column (update stages only) hasn't been dropped yet at
        # this point - unlike export_key_field just above, protect it here
        # rather than earlier, since the update branch further below still
        # needs it intact to build the Id mapping.
        protect = {c for c in (export_key_field, stage.get("match_key_column")) if c}
        # update stages must check updateable, not createable - audit
        # fields like CreatedDate/LastModifiedDate can be createable=True
        # (this org allows setting them at insert time) while still being
        # updateable=False (Salesforce never allows changing them once the
        # record exists) - confirmed in practice: Intake's own insert
        # succeeded sending these, then Intake_Update failed every row with
        # "Unable to create/update fields: CreatedDate, LastModifiedDate".
        flag = "updateable" if stage_type == "update" else "createable"
        field_meta = sf_runner.describe_sobject_fields(org_alias, stage["sobject"])
        df, dropped_cols = mapper.drop_noncreateable_columns(df, field_meta, protect_columns=protect, flag=flag)
        if dropped_cols:
            print(f"  [{name}] dropping {len(dropped_cols)} non-{flag} column(s) before "
                  f"insert: {', '.join(sorted(dropped_cols))}")

        # ---- Resume/idempotency (only possible where bookkeeping_field
        # gives us a real field to check the org against) ----
        original_keys = None
        if export_key_field and bookkeeping_field and stage_type in ("insert",):
            original_keys = sorted({v for v in df[bookkeeping_field] if v})
            scoped_query = mapper.build_scoped_query(stage["sobject"], bookkeeping_field, original_keys)
            existing = sf_runner.query(org_alias, scoped_query) if original_keys else []
            existing_keys = {r[bookkeeping_field] for r in existing}
            df, skip_count = _partition_by_existing(df, bookkeeping_field, existing_keys)
        else:
            skip_count = 0
            existing = []

        if df.empty and skip_count:
            print(f"  [{name}]: all {skip_count} row(s) already exist in org (by "
                  f"{bookkeeping_field}) - skipping insert")
            job = _skip_result(existing)
        else:
            if skip_count:
                print(f"  [{name}]: {skip_count} row(s) already exist in org - "
                      f"inserting only the remaining {len(df)}")
            mapped_path = f"{OUTPUT_DIR}/{name}_mapped.csv"
            df.to_csv(mapped_path, index=False)

            if stage_type == "upsert_users":
                job = sf_runner.bulk_upsert_chunked(
                    org_alias, stage["sobject"], mapped_path, stage["upsert_external_id"],
                    chunk_size=USER_UPSERT_CHUNK_SIZE, output_dir=OUTPUT_DIR)
            elif stage_type == "insert":
                job = sf_runner.bulk_insert(org_alias, stage["sobject"], mapped_path, output_dir=OUTPUT_DIR)
            elif stage_type == "update":
                ref_name = stage["match_against_reference"]
                if ref_name not in reference_tables:
                    raise KeyError(f"[{name}] update stage needs reference table '{ref_name}' "
                                    f"from an earlier insert stage - check stage order.")
                id_map = reference_tables[ref_name]
                match_key_column = stage["match_key_column"]
                df["Id"] = df[match_key_column].map(id_map)
                unmatched_ids = df["Id"].isna().sum()
                if unmatched_ids:
                    print(f"  WARNING [{name}]: {unmatched_ids} row(s) have no matching "
                          f"previously-inserted record - these rows will be skipped.")
                df = df[df["Id"].notna()]
                # match_key_column (e.g. OLD_ID) is bookkeeping-only, never a
                # real Salesforce field - unlike insert stages, `update` had
                # no equivalent of export_key_field's drop, so this rode
                # along into the CSV and broke the whole upsert job with
                # "InvalidBatch: Field name not found" once confirmed live.
                df = df.drop(columns=[match_key_column])
                mapped_path = f"{OUTPUT_DIR}/{name}_update_mapped.csv"
                df.to_csv(mapped_path, index=False)
                job = sf_runner.bulk_update(org_alias, stage["sobject"], mapped_path, output_dir=OUTPUT_DIR)
            else:
                raise ValueError(f"[{name}] unknown stage type: {stage_type}")

            print(f"  {job.succeeded} succeeded, {job.failed} failed {_format_result_paths(job)}")

            if export_key_field and bookkeeping_field and stage.get("export_as"):
                existing = sf_runner.query(org_alias, scoped_query)

        summary.append((name, job, skip_count, None))

        if stage.get("export_as") and bookkeeping_field:
            ref_map = mapper.build_lookup_map(pd.DataFrame(existing), bookkeeping_field)
            reference_tables[stage["export_as"]] = ref_map
            print(f"  [{name}] {len(ref_map)} record(s) available in reference table '{stage['export_as']}'")

    print("\n" + "=" * 60)
    print("FINAL SUMMARY")
    print("=" * 60)
    total_ok, total_fail = 0, 0
    for name, job, skip_count, tag_override in summary:
        if tag_override is not None:
            tag = tag_override
        elif job.job_id is None:
            tag = "  (already existed in org - insert skipped)"
        elif skip_count:
            tag = f"  ({skip_count} pre-existing row(s) already in org, not re-inserted)"
        else:
            tag = ""
        row_succeeded = job.succeeded + (skip_count if job.job_id is not None else 0)
        print(f"  {name:25s}  {row_succeeded:4d} succeeded  /  {job.failed:4d} failed{tag}")
        total_ok += row_succeeded
        total_fail += job.failed
    print("-" * 60)
    print(f"  {'TOTAL':25s}  {total_ok:4d} succeeded  /  {total_fail:4d} failed")
    if total_fail:
        print(f"\nInspect the *-failed-records.csv files in {OUTPUT_DIR}/, fix the source rows, and re-run.")

    if flow_name:
        print("\n" + "=" * 60)
        print(f"ACTION REQUIRED: please activate the Flow '{flow_name}' manually now.")
        print("=" * 60)

    return 0 if total_fail == 0 else 1


def main():
    parser = argparse.ArgumentParser(description="ICY sandbox test-data load")
    sub = parser.add_subparsers(dest="mode", required=True)

    p_validate = sub.add_parser("validate", help="Pre-flight checks only, loads no data")
    p_validate.add_argument("--org", required=True)

    p_deploy = sub.add_parser("deploy", help="Run the real load")
    p_deploy.add_argument("--org", required=True)
    p_deploy.add_argument(
        "--deliverability-confirmed", action="store_true",
        help="Confirms you've manually checked Setup > Deliverability > Access to Send "
             "Email = 'All Email' in the target org. Required - Salesforce has no API to "
             "read this setting, so deploy refuses to run without it.",
    )

    args = parser.parse_args()
    if args.mode == "validate":
        sys.exit(run_validate(args.org))
    elif args.mode == "deploy":
        sys.exit(run_deploy(args.org, args.deliverability_confirmed))


if __name__ == "__main__":
    main()
