#!/usr/bin/env python3
"""
load_test_data.py

Single entrypoint for the MAiD sandbox test-data load.

  STEP 0 (manual, before every deploy):
    Deactivate the "MAiD Prevent Duplicate Phn" Flow yourself in Setup.

  STEP 1 (manual, once per person):
    sf org login web --alias MAidQA

  STEP 2 (this script - validate first, then deploy):
    python scripts/load_test_data.py validate --org MAidQA
    python scripts/load_test_data.py deploy   --org MAidQA

  STEP 3 (manual, after deploy finishes):
    Reactivate the Flow yourself in Setup.

`validate` never writes to the org and never loads data - it's a local +
read-only pre-flight check (see run_validate()).

`deploy` performs the real load: Account -> export -> Case -> export ->
6 Forms. It does NOT deactivate or reactivate the Flow itself - it only
CHECKS whether the Flow is currently active before starting. If it's still
active, `deploy` halts immediately (no data touched) and tells you to
deactivate it manually first. Once you confirm it's off and re-run `deploy`,
it proceeds with the load, and reminds you at the end to reactivate the
Flow yourself - that reactivation is entirely manual, by design.

Original CSVs under data/ are never modified. All derived/mapped CSVs and
success/failure reports are written to output/, which is .gitignored.
"""
from __future__ import annotations
import argparse
import os
import sys
import yaml
import pandas as pd

sys.path.insert(0, os.path.dirname(__file__))
import mapper
import sf_runner


CONFIG_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), "mapping_config.yaml")
OUTPUT_DIR = "output"


def load_config() -> dict:
    with open(CONFIG_PATH) as f:
        return yaml.safe_load(f)


# --------------------------------------------------------------------------
# VALIDATE - safe, read-only, no data is loaded. Analogous in spirit to
# `sf project deploy validate`, but for data (Bulk API has no native dry-run,
# so this is our own pre-flight check).
# --------------------------------------------------------------------------
def run_validate(org_alias: str) -> int:
    cfg = load_config()
    problems = []

    print(f"== Checking org connection: {org_alias} ==")
    connected = False
    try:
        org_info = sf_runner.check_org_connection(org_alias)
        print(f"  OK - connected as {org_info.get('username', '?')} ({org_info.get('instanceUrl', '?')})")
        connected = True
    except Exception as e:
        problems.append(f"Cannot connect to org '{org_alias}': {e}")
        print(f"  FAILED: {e}")

    print("\n== Checking target org is a sandbox (this tool must never run against Production) ==")
    confirmed_sandbox = False
    is_production = False
    if not connected:
        print("  SKIPPED - org connection failed above, cannot check sandbox status until that's fixed.")
    else:
        try:
            if sf_runner.is_sandbox(org_alias):
                print("  The auth/alias org where we are performing the data load is "
                      "currently a sandbox environment. Please proceed with data load")
                confirmed_sandbox = True
            else:
                is_production = True
                problems.append(
                    "The auth/alias org where we are performing the data load is currently "
                    "a Production environment. Please change it to a Sandbox environment before "
                    "proceeding with the data load."
                )
                print("  FAILED: The auth/alias org where we are performing the data load is "
                      "currently a Production environment. Please change it to a Sandbox environment "
                      "before proceeding with the data load.")
        except Exception as e:
            problems.append(f"Could not determine sandbox status for org '{org_alias}': {e}")
            print(f"  FAILED: {e}")

    if is_production:
        # Stop immediately rather than running every remaining check (CSV,
        # object/field describes, date formats, join coverage) against a
        # CONFIRMED Production org - those are all read-only, but there's no
        # reason to keep making live calls against the wrong org once we
        # already know it's the wrong org, and burying this one critical
        # problem inside a long list of unrelated object/field mismatches
        # (production won't have these custom objects/fields either) would
        # make the actual issue harder to spot, not easier.
        print("\n" + "=" * 60)
        print("VALIDATION FAILED - 1 problem(s) found:\n")
        print(f"  - {problems[-1]}")
        print("\nFix the above before running `deploy`.")
        return 1

    print("\n== Checking input CSVs exist and columns match config ==")
    all_objects = [("account", cfg["account"]), ("case", cfg["case"])] + \
                  [(f["name"], f) for f in cfg["forms"]]
    missing_files = {name for name, obj_cfg in all_objects if not os.path.exists(obj_cfg["input_csv"])}

    for name, obj_cfg in all_objects:
        path = obj_cfg["input_csv"]
        if not os.path.exists(path):
            problems.append(f"[{name}] input CSV not found: {path}")
            print(f"  [{name}] MISSING FILE: {path}")
            continue
        df = mapper.load_csv(path)
        print(f"  [{name}] {path} - {len(df)} rows, {len(df.columns)} columns")

        for lk in obj_cfg.get("lookups", []):
            if lk["source_column"] not in df.columns:
                problems.append(f"[{name}] source_column '{lk['source_column']}' not in {path}")
            if lk["target_column"] not in df.columns:
                problems.append(f"[{name}] target_column '{lk['target_column']}' not in {path}")

        # Salesforce API field names never contain spaces - any column that
        # does is almost certainly a spreadsheet-only helper (e.g. "College
        # ID") that will make the Bulk API reject the WHOLE load with "Field
        # name not found", not just skip that column. If it's declared with
        # drop_source: true (or is the record_type_mapping source column),
        # it'll be removed before insert and is fine; otherwise, flag it here
        # instead of only discovering it after a live deploy attempt fails.
        handled_space_columns = {lk["source_column"] for lk in obj_cfg.get("lookups", []) if lk.get("drop_source")}
        rt_cfg = obj_cfg.get("record_type_mapping")
        if rt_cfg:
            handled_space_columns.add(rt_cfg["source_column"])
        for col in df.columns:
            if " " in col and col not in handled_space_columns:
                problems.append(
                    f"[{name}] column '{col}' contains a space - Salesforce API field names "
                    f"never do, so this will break the real Bulk API load unless it's marked "
                    f"drop_source: true (or is a record_type_mapping source) in mapping_config.yaml"
                )

    print("\n== Checking target org field/object names (catches typos in mapping_config.yaml) ==")
    field_types_by_object: dict[str, dict[str, dict]] = {}
    if not problems or all("Cannot connect" not in p for p in problems):
        for name, obj_cfg in all_objects:
            sobject = obj_cfg["sobject"]
            try:
                fields = sf_runner.describe_sobject_fields(org_alias, sobject)
            except Exception as e:
                problems.append(f"[{name}] could not describe sobject '{sobject}': {e}")
                continue
            field_types_by_object[name] = fields
            for lk in obj_cfg.get("lookups", []):
                if lk["target_column"] not in fields:
                    problems.append(
                        f"[{name}] target_column '{lk['target_column']}' does not exist "
                        f"on sobject '{sobject}' in org '{org_alias}'"
                    )
    else:
        print("  SKIPPED - org connection failed above, cannot describe sobjects until that's fixed.")

    print("\n== Checking date field formats (org 'date' fields must end up YYYY-MM-DD - "
          "bare M/D/YYYY is auto-converted at deploy time, anything else fails the real load) ==")
    if not field_types_by_object:
        print("  SKIPPED - org field types unavailable (see sobject/field check above).")
    else:
        for name, obj_cfg in all_objects:
            if name in missing_files:
                continue
            field_types = field_types_by_object.get(name)
            if not field_types:
                continue  # describe failed for this object above, already reported
            df = mapper.load_csv(obj_cfg["input_csv"])
            date_columns = [c for c in df.columns if field_types.get(c, {}).get("type") == "date"]
            for col in date_columns:
                convertible, unrecognized = mapper.analyze_date_column(df[col])
                if unrecognized:
                    sample = ", ".join(repr(v) for v in unrecognized[:5])
                    problems.append(
                        f"[{name}] column '{col}' has {len(unrecognized)} value(s) that are neither "
                        f"YYYY-MM-DD nor a recognizable M/D/YYYY date, e.g. {sample} - these rows "
                        f"will fail the real Bulk API load"
                    )
                elif convertible:
                    print(f"  [{name}] column '{col}': {convertible} value(s) will be auto-converted "
                          f"from M/D/YYYY to YYYY-MM-DD at deploy time")

    print("\n== Checking for non-createable columns (formula/system/FLS-restricted fields the Bulk API "
          "would reject - these are dropped automatically at deploy time) ==")
    if not field_types_by_object:
        print("  SKIPPED - org field types unavailable (see sobject/field check above).")
    else:
        for name, obj_cfg in all_objects:
            if name in missing_files:
                continue
            field_types = field_types_by_object.get(name)
            if not field_types:
                continue  # describe failed for this object above, already reported
            df = mapper.load_csv(obj_cfg["input_csv"])
            _, dropped = mapper.drop_noncreateable_columns(df, field_types)
            if dropped:
                print(f"  [{name}] {len(dropped)} column(s) will be dropped before insert (not "
                      f"createable in this org): {', '.join(sorted(dropped))}")

    print("\n== Checking join-key coverage (how many rows WOULD match, without loading anything) ==")
    if "account" in missing_files or "case" in missing_files:
        print("  SKIPPED: Account.csv and/or Case.csv missing (see file check above) - cannot compute any coverage.")
    else:
        account_df = mapper.load_csv(cfg["account"]["input_csv"])
        case_df = mapper.load_csv(cfg["case"]["input_csv"])
        account_keys = set(account_df[cfg["account"]["export_key_field"]]) - {""}
        case_lk = cfg["case"]["lookups"][0]
        matched = case_df[case_lk["source_column"]].isin(account_keys).sum()
        print(f"  [case] {matched}/{len(case_df)} rows have a matching Account.{cfg['account']['export_key_field']}")
        if matched < len(case_df):
            problems.append(f"[case] {len(case_df) - matched} row(s) reference a College_ID not present in Account.csv")

        case_keys = set(case_df[cfg["case"]["export_key_field"]]) - {""}
        for f in cfg["forms"]:
            if f["name"] in missing_files:
                print(f"  [{f['name']}] SKIPPED - input file missing (see file check above)")
                continue
            df = mapper.load_csv(f["input_csv"])
            phn_lk = next(lk for lk in f["lookups"] if lk["map"] == "case")
            matched = df[phn_lk["source_column"]].isin(case_keys).sum()
            print(f"  [{f['name']}] {matched}/{len(df)} rows have a matching Case.{cfg['case']['export_key_field']}")
            if matched < len(df):
                problems.append(f"[{f['name']}] {len(df) - matched} row(s) reference a PHN not present in Case.csv")

    print("\n" + "=" * 60)
    if problems:
        print(f"VALIDATION FAILED - {len(problems)} problem(s) found:\n")
        for p in problems:
            print(f"  - {p}")
        print("\nFix the above before running `deploy`.")
        return 1
    else:
        print("VALIDATION PASSED - safe to run `deploy`.")
        print("\nReminder (manual step, not automated):")
        print("  Please have a human confirm Record Type Names on Account/Case")
        print("  look correct before deploying - see MAiD_-_Test_Data_Set_and_Procedure doc.")
        if confirmed_sandbox:
            print(f"\nConfirmed: target org '{org_alias}' is a Sandbox, not Production - safe to load test data.")
        return 0


# --------------------------------------------------------------------------
# DEPLOY - the real load. Checks the Flow's status but does NOT touch it -
# deactivation and reactivation are entirely manual, by design (see module
# docstring). If the Flow is active, halts before touching any data.
# --------------------------------------------------------------------------
def run_deploy(org_alias: str) -> int:
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    cfg = load_config()
    flow_name = cfg["flow_api_name"]
    summary = []

    # Hard safety gate, checked first and before anything else - this tool
    # must never load test data into Production. `validate` checks this too,
    # but nothing forces someone to run `validate` before `deploy`, so this
    # has to be enforced here independently, not just recommended there.
    print(f"== Checking target org is a sandbox: {org_alias} ==")
    if not sf_runner.is_sandbox(org_alias):
        print("\nThe auth/alias org where we are performing the data load is currently a "
              "Production environment. Please change it to a Sandbox environment before proceeding "
              "with the data load.")
        return 1
    print("  The auth/alias org where we are performing the data load is currently a "
          "sandbox environment. Please proceed with data load")

    print(f"== Checking Flow status: {flow_name} ==")
    active_version_id = sf_runner.get_active_flow_version_id(org_alias, flow_name)

    if active_version_id:
        print(f"\nThe flow: {flow_name} is active and it prevents the dataload. "
              f"To begin the data load please de-activate this flow and once all the "
              f"data load work is done please activate it manually.")
        return 1

    print(f"  Confirmed: Flow '{flow_name}' is deactivated. Proceeding with data load.")

    # ---- Account ----
    acc_cfg = cfg["account"]
    acc_df = mapper.normalize_us_dates(mapper.load_csv(acc_cfg["input_csv"]))

    rt_cfg = acc_cfg.get("record_type_mapping")
    if rt_cfg:
        print(f"\n== Resolving Account Record Types ({rt_cfg['source_column']} -> {rt_cfg['target_column']}) ==")
        rt_records = sf_runner.query(
            org_alias, f"SELECT Id, Name, DeveloperName FROM RecordType WHERE SObjectType = '{acc_cfg['sobject']}'"
        )
        record_type_map: dict = {}
        for r in rt_records:
            if r.get("Name"):
                record_type_map.setdefault(r["Name"], r["Id"])
            if r.get("DeveloperName"):
                record_type_map.setdefault(r["DeveloperName"], r["Id"])
        print(f"  {len(rt_records)} Record Type(s) found in org for {acc_cfg['sobject']}")

        rt_lookup = [{**rt_cfg, "map": "record_type", "drop_source": True}]
        rt_result = mapper.apply_lookups(acc_df, rt_lookup, {"record_type": record_type_map})
        acc_df = rt_result.dataframe
        if rt_result.unmatched_rows:
            print(f"  WARNING: {len(rt_result.unmatched_rows)} row(s) have a "
                  f"'{rt_cfg['source_column']}' value that doesn't match any Record Type "
                  f"in the org - {rt_cfg['target_column']} left blank for these rows:")
            for u in rt_result.unmatched_rows[:10]:
                print(f"    row {u['row_index']}: '{u['source_value']}'")

    had_owner_id = "OwnerId" in acc_df.columns
    acc_df = mapper.drop_owner_id(acc_df)
    if had_owner_id:
        print("  Dropping stale OwnerId column - Salesforce will default it to the running user.")

    acc_field_meta = sf_runner.describe_sobject_fields(org_alias, acc_cfg["sobject"])
    acc_df, acc_dropped_cols = mapper.drop_noncreateable_columns(acc_df, acc_field_meta)
    if acc_dropped_cols:
        print(f"  Dropping {len(acc_dropped_cols)} non-createable column(s) before insert: "
              f"{', '.join(sorted(acc_dropped_cols))}")

    # Only ask the org about the College_IDs actually present in this CSV -
    # querying the whole Account table (as an earlier version did) also pulls
    # back any pre-existing, unrelated Accounts with a blank College_ID__pc,
    # which made build_lookup_map() raise "duplicate key: [nan]" and crash
    # the run before Case/Forms ever loaded.
    acc_keys = sorted({v for v in acc_df[acc_cfg["export_key_field"]] if v})
    acc_export_query = _scoped_query(
        f"Id, {acc_cfg['export_key_field']}", acc_cfg["sobject"], acc_cfg["export_key_field"], acc_keys
    )
    existing_acc = sf_runner.query(org_alias, acc_export_query) if acc_keys else []
    existing_acc_keys = {r[acc_cfg["export_key_field"]] for r in existing_acc}
    acc_to_insert, acc_skip_count = _partition_by_existing(acc_df, acc_cfg["export_key_field"], existing_acc_keys)

    if acc_to_insert.empty:
        print(f"\n== Account: all {len(acc_keys)} row(s) already exist in org (by "
              f"{acc_cfg['export_key_field']}) - skipping insert ==")
        acc_job = _skip_result(existing_acc)
        acc_summary_skip = 0
    else:
        if acc_skip_count:
            print(f"\n== Account: {acc_skip_count}/{len(acc_df)} row(s) already exist in org - "
                  f"inserting only the remaining {len(acc_to_insert)} ==")
        acc_mapped_path = f"{OUTPUT_DIR}/Account_mapped.csv"
        acc_to_insert.to_csv(acc_mapped_path, index=False)

        print("\n== Loading Account ==")
        acc_job = sf_runner.bulk_insert(org_alias, acc_cfg["sobject"], acc_mapped_path)
        print(f"  {acc_job.succeeded} succeeded, {acc_job.failed} failed {_format_result_paths(acc_job)}")

        print("\n== Exporting new Account IDs ==")
        existing_acc = sf_runner.query(org_alias, acc_export_query)
        acc_summary_skip = acc_skip_count

    summary.append(("Account", acc_job, acc_summary_skip))
    account_map = mapper.build_lookup_map(pd.DataFrame(existing_acc), acc_cfg["export_key_field"])
    print(f"  {len(account_map)} Account records exported")

    # ---- Case ----
    case_cfg = cfg["case"]
    case_df = mapper.normalize_us_dates(mapper.load_csv(case_cfg["input_csv"]))
    had_owner_id = "OwnerId" in case_df.columns
    case_df = mapper.drop_owner_id(case_df)
    if had_owner_id:
        print("  Dropping stale OwnerId column - Salesforce will default it to the running user.")

    case_keys = sorted({v for v in case_df[case_cfg["export_key_field"]] if v})
    case_export_query = _scoped_query(
        f"Id, {case_cfg['export_key_field']}", case_cfg["sobject"], case_cfg["export_key_field"], case_keys
    )
    existing_case = sf_runner.query(org_alias, case_export_query) if case_keys else []
    existing_case_keys = {r[case_cfg["export_key_field"]] for r in existing_case}
    case_to_insert, case_skip_count = _partition_by_existing(case_df, case_cfg["export_key_field"], existing_case_keys)

    if case_to_insert.empty:
        print(f"\n== Case: all {len(case_keys)} row(s) already exist in org (by "
              f"{case_cfg['export_key_field']}) - skipping insert ==")
        case_job = _skip_result(existing_case)
        case_summary_skip = 0
    else:
        if case_skip_count:
            print(f"\n== Case: {case_skip_count}/{len(case_df)} row(s) already exist in org - "
                  f"inserting only the remaining {len(case_to_insert)} ==")
        case_result = mapper.apply_lookups(case_to_insert, case_cfg["lookups"], {"account": account_map})
        # Dropped AFTER apply_lookups, not before - College_ID__c is a formula
        # field on Case (not createable) but is still needed as the join key
        # to resolve Practitioner_Name__c above; only strip it once it's no
        # longer needed as insert data.
        case_field_meta = sf_runner.describe_sobject_fields(org_alias, case_cfg["sobject"])
        case_result.dataframe, case_dropped_cols = mapper.drop_noncreateable_columns(
            case_result.dataframe, case_field_meta
        )
        if case_dropped_cols:
            print(f"  Dropping {len(case_dropped_cols)} non-createable column(s) before insert: "
                  f"{', '.join(sorted(case_dropped_cols))}")
        case_mapped_path = f"{OUTPUT_DIR}/Case_mapped.csv"
        case_result.dataframe.to_csv(case_mapped_path, index=False)
        _report_unmatched("Case", case_result)

        print("\n== Loading Case ==")
        case_job = sf_runner.bulk_insert(org_alias, case_cfg["sobject"], case_mapped_path)
        print(f"  {case_job.succeeded} succeeded, {case_job.failed} failed {_format_result_paths(case_job)}")

        print("\n== Exporting new Case IDs ==")
        existing_case = sf_runner.query(org_alias, case_export_query)
        case_summary_skip = case_skip_count

    summary.append(("Case", case_job, case_summary_skip))
    case_map = mapper.build_lookup_map(pd.DataFrame(existing_case), case_cfg["export_key_field"])
    print(f"  {len(case_map)} Case records exported")

    # ---- Forms ----
    # Forms have no export_key_field of their own (nothing downstream depends
    # on them), so "already loaded" is checked row-by-row via the Case__c
    # value each row resolves to - if a Form record already points at that
    # Case, that specific row was already inserted by an earlier (partial)
    # run and is left alone; only rows whose Case__c isn't there yet get
    # inserted, so a run that died partway through a Form still completes it
    # on retry instead of re-inserting the rows that already made it in.
    lookup_maps = {"account": account_map, "case": case_map}
    for f in cfg["forms"]:
        print(f"\n== Preparing {f['name']} ==")
        df = mapper.normalize_us_dates(mapper.load_csv(f["input_csv"]))
        had_owner_id = "OwnerId" in df.columns
        df = mapper.drop_owner_id(df)
        if had_owner_id:
            print(f"  {f['name']}: dropping stale OwnerId column - Salesforce will default it to the running user.")
        result = mapper.apply_lookups(df, f["lookups"], lookup_maps)
        _report_unmatched(f["name"], result)

        form_field_meta = sf_runner.describe_sobject_fields(org_alias, f["sobject"])
        result.dataframe, form_dropped_cols = mapper.drop_noncreateable_columns(result.dataframe, form_field_meta)
        if form_dropped_cols:
            print(f"  {f['name']}: dropping {len(form_dropped_cols)} non-createable column(s) before "
                  f"insert: {', '.join(sorted(form_dropped_cols))}")

        case_lk = next(lk for lk in f["lookups"] if lk["map"] == "case")
        form_case_ids = sorted({v for v in result.dataframe[case_lk["target_column"]] if v})
        existing_form = sf_runner.query(
            org_alias,
            _scoped_query(f"Id, {case_lk['target_column']}", f["sobject"], case_lk["target_column"], form_case_ids),
        ) if form_case_ids else []
        existing_form_case_ids = {r[case_lk["target_column"]] for r in existing_form}
        form_to_insert, form_skip_count = _partition_by_existing(
            result.dataframe, case_lk["target_column"], existing_form_case_ids
        )
        mapped_path = f"{OUTPUT_DIR}/{f['name']}_mapped.csv"
        form_to_insert.to_csv(mapped_path, index=False)

        if form_to_insert.empty:
            print(f"  {f['name']}: all {len(form_case_ids)} row(s) already exist in org (by "
                  f"{case_lk['target_column']}) - skipping insert")
            job = _skip_result(existing_form)
            form_summary_skip = 0
        else:
            if form_skip_count:
                print(f"  {f['name']}: {form_skip_count}/{len(result.dataframe)} row(s) already exist in org - "
                      f"inserting only the remaining {len(form_to_insert)}")
            print(f"== Loading {f['name']} ==")
            job = sf_runner.bulk_insert(org_alias, f["sobject"], mapped_path)
            print(f"  {job.succeeded} succeeded, {job.failed} failed {_format_result_paths(job)}")
            form_summary_skip = form_skip_count

        summary.append((f["name"], job, form_summary_skip))

    # ---- Final consolidated summary ----
    print("\n" + "=" * 60)
    print("FINAL SUMMARY")
    print("=" * 60)
    total_ok, total_fail = 0, 0
    for name, job, skip_count in summary:
        if job.job_id is None:
            tag = "  (already existed in org - insert skipped)"
        elif skip_count:
            tag = f"  ({skip_count} pre-existing row(s) already in org, not re-inserted)"
        else:
            tag = ""
        # succeeded here = newly inserted this run + whatever was already
        # there and correctly left alone, so it reads as "how many now
        # correctly exist," not just "how many did this run touch."
        row_succeeded = job.succeeded + (skip_count if job.job_id is not None else 0)
        print(f"  {name:15s}  {row_succeeded:4d} succeeded  /  {job.failed:4d} failed{tag}")
        total_ok += row_succeeded
        total_fail += job.failed
    print("-" * 60)
    print(f"  {'TOTAL':15s}  {total_ok:4d} succeeded  /  {total_fail:4d} failed")
    if total_fail:
        print(f"\nInspect the *-failed-records.csv files in {OUTPUT_DIR}/, fix the source rows, and re-run.")

    # Printed last, after the summary, on purpose - this is the one manual
    # step `deploy` can never do for you (see module docstring), and it's
    # easy to miss if it's buried above the summary table instead of being
    # the final thing on screen.
    print("\n" + "=" * 60)
    print(f"ACTION REQUIRED: please activate the Flow '{flow_name}' manually now.")
    print("=" * 60)

    return 0 if total_fail == 0 else 1


def _soql_string_list(values) -> str:
    """Renders values as a quoted, comma-separated SOQL literal list for an
    IN (...) clause, escaping backslashes/quotes defensively (College_ID/PHN
    values are expected to be plain alphanumeric, but this is cheap insurance
    against a stray apostrophe breaking the query)."""
    return ", ".join("'" + str(v).replace("\\", "\\\\").replace("'", "\\'") + "'" for v in values)


def _scoped_query(select_clause: str, sobject: str, field: str, values) -> str:
    """Builds a SELECT ... WHERE <field> IN (...) query scoped to exactly the
    keys we care about, instead of pulling every row of the sobject. Two
    reasons this matters: (1) a target org can have pre-existing, unrelated
    records (e.g. Accounts with a blank College_ID__pc) that would otherwise
    get swept into the export and confuse the join/dedup logic, and (2) it's
    what makes the "already loaded" checks below meaningful - without
    scoping, every object would look "non-empty" in any real org."""
    if not values:
        return f"SELECT {select_clause} FROM {sobject} LIMIT 0"
    return f"SELECT {select_clause} FROM {sobject} WHERE {field} IN ({_soql_string_list(values)})"


def _partition_by_existing(df: pd.DataFrame, key_column: str, existing_keys: set) -> tuple[pd.DataFrame, int]:
    """Splits df's rows into (rows still needing insert, count already in the
    org), based on whether key_column's value for that row is already among
    existing_keys. This is what makes a re-run after a partial failure safe:
    if 30 of 42 Accounts made it in before the run died, only the other 12
    get inserted here, instead of either re-inserting all 42 (duplicates) or
    skipping all 42 because *some* already exist (leaving 12 missing
    forever)."""
    already_here = df[key_column].isin(existing_keys)
    return df[~already_here].reset_index(drop=True), int(already_here.sum())


def _skip_result(existing_records: list[dict]) -> sf_runner.BulkJobResult:
    """A stand-in BulkJobResult for an object whose rows were found to
    already exist in the org - job_id is left as None, which is what the
    final summary and _format_result_paths() use to recognize a skipped
    (not actually run) step rather than a completed bulk job."""
    n = len(existing_records)
    return sf_runner.BulkJobResult(None, n, n, 0, None, None)


def _format_result_paths(job) -> str:
    if job.job_id is None:
        return "(no job run - see skip note above)"
    if job.success_records_path or job.failed_records_path:
        return f"(details: {job.success_records_path}, {job.failed_records_path})"
    return (f"(run 'sf data import resume --job-id {job.job_id} --target-org <org>' "
            f"for full per-row results if needed - counts above are already reliable)")


def _report_unmatched(name: str, result: mapper.LookupResult) -> None:
    if result.unmatched_rows:
        print(f"  WARNING [{name}]: {len(result.unmatched_rows)} row(s) had an unresolved lookup "
              f"(blanked out, not dropped) - see below:")
        for r in result.unmatched_rows[:10]:
            print(f"    row {r['row_index']}: {r['source_column']}='{r['source_value']}' "
                  f"-> {r['target_column']} ({r['reason']})")
        if len(result.unmatched_rows) > 10:
            print(f"    ... and {len(result.unmatched_rows) - 10} more")


def main():
    parser = argparse.ArgumentParser(description="MAiD sandbox test-data load")
    sub = parser.add_subparsers(dest="mode", required=True)

    p_validate = sub.add_parser("validate", help="Pre-flight checks only, loads no data")
    p_validate.add_argument("--org", required=True, help="sf CLI target-org alias")

    p_deploy = sub.add_parser("deploy", help="Run the real load")
    p_deploy.add_argument("--org", required=True, help="sf CLI target-org alias")

    args = parser.parse_args()
    if args.mode == "validate":
        sys.exit(run_validate(args.org))
    elif args.mode == "deploy":
        sys.exit(run_deploy(args.org))


if __name__ == "__main__":
    main()
