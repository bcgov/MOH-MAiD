#!/usr/bin/env python3
"""
deactivate_users.py (ICY)

Standalone, one-time-per-org maintenance script - NOT part of the
load_test_data.py pipeline. This automates "ICY Test Data Seeding
Procedure" PDF Steps 1-2 (export Active Users, deactivate all but a
handful to free Salesforce User licenses) so the Users stage in
mapping_config.yaml has enough license capacity to upsert the ~298 ICY
test personas without hitting LICENSE_LIMIT_EXCEEDED.

Portable across orgs on purpose - nothing here is a hardcoded Id. The
exempt list is resolved fresh in whichever org --org points at, the same
"identifier resolved per-run" approach mapping_config.yaml already uses
for RecordTypeId (developer_name) and OwnerId (set_fields_from_query):
  - the admin user, matched the same way as everywhere else in this tool
    (Username LIKE 'admin.user@%' AND an ICY-named UserRole)
  - 3 named individuals from the source PDF's own exempt list, matched by
    their GUID username prefix - confirmed to stay identical across every
    sandbox refresh of this org (only the ".sosehfdv"/".soseuat"/etc.
    domain suffix differs), so this does NOT need editing per sandbox.

Each exempt pattern must resolve to EXACTLY one user - if it resolves to
zero or more than one, this refuses to run rather than risk deactivating
(or failing to exempt) the wrong real person.

Usage:
  python scripts/deactivate_users.py --org <alias>              # dry run (default) - queries and reports only, touches nothing
  python scripts/deactivate_users.py --org <alias> --confirm    # actually deactivates

Always writes an audit report to output/deactivate_users_<org>_report.csv
(Id, Username, Name, OldIsActive, NewIsActive) so the change can be
reviewed - or manually reversed - later if business disagrees with who was
kept active.
"""
from __future__ import annotations
import argparse
import csv
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import sf_runner

OUTPUT_DIR = "output"

# GUID prefixes are stable across sandbox refreshes of this org; only the
# domain suffix (@moh.com.bcmohmaid.<sandbox>) changes per environment.
EXEMPT_USERNAME_LIKE_PATTERNS = [
    "admin.user@%",
    "d4c79006-1d5a-4bb9-895a-6ee8a17dec8c@%",
    "939df4bb-4b4e-4c83-b2af-b2d9bd1a4368@%",
    "af55d4b5-2b4c-4f29-af1b-70bc84c51bff@%",
]

DEFAULT_LICENSE = "Salesforce"


def resolve_exempt_ids(org_alias: str) -> set[str]:
    exempt_ids = set()
    for pattern in EXEMPT_USERNAME_LIKE_PATTERNS:
        query = f"SELECT Id, Username, Name FROM User WHERE Username LIKE '{pattern}'"
        records = sf_runner.query(org_alias, query)
        if len(records) != 1:
            raise SystemExit(
                f"FATAL: exempt pattern '{pattern}' matched {len(records)} user(s) in "
                f"org '{org_alias}' (expected exactly 1) - refusing to proceed with an "
                f"ambiguous exempt list. Records: {records}"
            )
        r = records[0]
        print(f"  Exempt: {r['Username']} ({r['Name']}) - {r['Id']}")
        exempt_ids.add(r["Id"])
    return exempt_ids


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Deactivate active Users (except a fixed exempt list) to free "
                    "Salesforce User licenses before the ICY Users stage."
    )
    parser.add_argument("--org", required=True)
    parser.add_argument("--license", default=DEFAULT_LICENSE,
                         help=f"UserLicense.MasterLabel to scope deactivation to (default: {DEFAULT_LICENSE})")
    parser.add_argument("--confirm", action="store_true",
                         help="Actually perform the deactivation. Without this flag, runs "
                              "a dry run only - queries and reports what WOULD happen, "
                              "touches nothing.")
    args = parser.parse_args()

    print(f"== Resolving exempt list in org '{args.org}' ==")
    exempt_ids = resolve_exempt_ids(args.org)

    print(f"\n== Querying active users with license '{args.license}' in org '{args.org}' ==")
    query = (
        f"SELECT Id, Username, Name FROM User "
        f"WHERE IsActive = true AND Profile.UserLicense.MasterLabel = '{args.license}'"
    )
    active = sf_runner.query(args.org, query)
    candidates = [r for r in active if r["Id"] not in exempt_ids]
    print(f"  {len(active)} active user(s) total, {len(candidates)} candidate(s) for "
          f"deactivation ({len(active) - len(candidates)} exempt)")

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    report_path = f"{OUTPUT_DIR}/deactivate_users_{args.org}_report.csv"

    if not args.confirm:
        print(f"\nDRY RUN - nothing has been touched. Re-run with --confirm to actually "
              f"deactivate these {len(candidates)} user(s).")
        with open(report_path, "w", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(["Id", "Username", "Name", "OldIsActive", "NewIsActive", "Status"])
            for r in candidates:
                writer.writerow([r["Id"], r["Username"], r["Name"], "true", "false", "DRY_RUN_NOT_APPLIED"])
        print(f"Preview report written to {report_path}")
        return 0

    # Bulk API 2.0 gives clients no control over its internal chunk size, and
    # this org has a non-bulkified User trigger (UserPermissionsTrigger) that
    # loops per-record instead of using bulk DML/SOQL - confirmed to trip TWO
    # separate governor limits depending on chunk size: "Too many DML
    # statements: 151" at ~200 records/transaction, and "Too many SOQL
    # queries: 201" at 100 records/transaction (implying ~2 non-bulkified
    # SOQL queries per record - a much tighter ceiling than the DML one,
    # since the default synchronous SOQL limit is only 100/transaction).
    # Using a notably smaller chunk size than either failure point leaves
    # real margin against both limits at once (and whatever else might be
    # lurking in this trigger that hasn't been hit yet).
    CHUNK_SIZE = 25
    print(f"\n== Deactivating {len(candidates)} user(s) in chunks of {CHUNK_SIZE} "
          f"(this org's User trigger isn't bulk-safe past ~150 DML statements/transaction) ==")
    total_succeeded, total_failed = 0, 0
    report_rows = []
    for i in range(0, len(candidates), CHUNK_SIZE):
        chunk = candidates[i:i + CHUNK_SIZE]
        chunk_num = i // CHUNK_SIZE + 1
        mapped_path = f"{OUTPUT_DIR}/deactivate_users_{args.org}_chunk{chunk_num}_mapped.csv"
        with open(mapped_path, "w", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(["Id", "IsActive"])
            for r in chunk:
                writer.writerow([r["Id"], "false"])
        job = sf_runner.bulk_update(args.org, "User", mapped_path, output_dir=OUTPUT_DIR)
        print(f"  chunk {chunk_num} ({len(chunk)} records): {job.succeeded} succeeded, {job.failed} failed")
        total_succeeded += job.succeeded
        total_failed += job.failed
        for r in chunk:
            report_rows.append([r["Id"], r["Username"], r["Name"], "true", "false"])

    print(f"\nTOTAL: {total_succeeded} succeeded, {total_failed} failed")

    with open(report_path, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["Id", "Username", "Name", "OldIsActive", "NewIsActive"])
        writer.writerows(report_rows)
    print(f"Audit report written to {report_path}")

    if total_failed:
        print(f"\nInspect the *-failed-records.csv files in {OUTPUT_DIR}/ for details.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
