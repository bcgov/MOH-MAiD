"""
sf_runner.py

Every call out to the Salesforce CLI lives in this one module, on purpose -
it's the only place in the codebase that touches the network/org, which makes
it the one thing that can't be unit tested offline (see tests/test_mapper.py
for what CAN be tested without an org).

Requires: Salesforce CLI (`sf`) installed and already authenticated
(`sf org login web --alias <org>`) before any of these are called.
"""
from __future__ import annotations
import csv
import json
import os
import re
import subprocess
from dataclasses import dataclass
from typing import Optional


class SfCommandError(RuntimeError):
    pass


def _run_raw(cmd: list[str], cwd: Optional[str] = None) -> tuple[int, str, str]:
    """Runs cmd and returns (returncode, stdout, stderr) without raising,
    regardless of exit code - most callers want _run() below instead, which
    raises on failure. This exists for bulk job commands, where a non-zero
    exit doesn't necessarily mean "nothing useful happened" - see
    _run_bulk_job()'s docstring."""
    is_windows = os.name == "nt"
    result = subprocess.run(
        cmd, capture_output=True, text=True, shell=is_windows,
        encoding="utf-8", errors="replace", cwd=cwd,
    )
    return result.returncode, result.stdout, result.stderr


def _run(cmd: list[str], cwd: Optional[str] = None) -> str:
    returncode, stdout, stderr = _run_raw(cmd, cwd=cwd)
    if returncode != 0:
        raise SfCommandError(f"Command failed: {' '.join(cmd)}\nSTDERR:\n{stderr}\nSTDOUT:\n{stdout}")
    return stdout


def check_org_connection(org_alias: str) -> dict:
    """Confirm the org alias is authenticated and reachable. Used by `validate`."""
    out = _run(["sf", "org", "display", "--target-org", org_alias, "--json"])
    return json.loads(out)["result"]


def describe_sobject_fields(org_alias: str, sobject: str) -> dict[str, dict]:
    """Return a dict of field API name -> {"type": ..., "createable": ...,
    "updateable": ...} on an object. Used by `validate`/`deploy` to catch
    typos in mapping_config.yaml, to catch date-format problems in the
    source CSVs, and to drop formula/system/FLS-restricted columns the Bulk
    API would otherwise reject the whole row for.

    createable and updateable are tracked separately (not just one
    "creatable-ish" flag) because they genuinely diverge for audit fields:
    CreatedDate/CreatedById/LastModifiedDate/LastModifiedById can be
    createable=True (e.g. a "Set Audit Fields upon Record Creation"
    permission enabling them at insert time) while still being
    updateable=False (Salesforce never allows changing them after the
    record exists, regardless of that permission) - confirmed in practice:
    an insert stage succeeded sending these, then the matching update pass
    on the same object failed with "Unable to create/update fields:
    CreatedDate, LastModifiedDate" for every row."""
    out = _run(["sf", "sobject", "describe", "--sobject", sobject, "--target-org", org_alias, "--json"])
    data = json.loads(out)["result"]
    return {f["name"]: {"type": f["type"], "createable": f.get("createable", True),
                         "updateable": f.get("updateable", True)}
            for f in data.get("fields", [])}


@dataclass
class BulkJobResult:
    job_id: Optional[str]
    processed: int
    succeeded: int
    failed: int
    success_records_path: Optional[str]
    failed_records_path: Optional[str]


def _run_bulk_job(cmd: list[str], org_alias: str, output_dir: str) -> BulkJobResult:
    """Shared logic for insert/upsert bulk jobs.

    IMPORTANT: the Salesforce CLI exits non-zero ("FailedRecordDetailsError")
    whenever ANY row in the batch fails - even though the underlying Bulk
    API job completed normally and processed every other row just fine.
    Raising on any non-zero exit (as an earlier version of this function
    did) would turn a real, informative "36 succeeded / 4 failed" result
    into an unhandled crash that kills the whole deploy before later stages
    ever run. Using _run_raw() here lets us inspect the response either
    way: on a clean exit it's the normal {"status": 0, "result": {...}}
    envelope; on this specific failure mode it's an error envelope that
    still carries "data": {"jobId": ...}, which is all fetch_bulk_results()
    below needs to pull the real per-row results.
    """
    returncode, out, err = _run_raw(cmd)
    try:
        payload = json.loads(out)
    except json.JSONDecodeError:
        raise SfCommandError(
            f"Command returned non-JSON output (exit {returncode}): {' '.join(cmd)}\n"
            f"STDERR:\n{err}\nSTDOUT:\n{out}"
        )

    if payload.get("status") == 0:
        job_info = payload["result"]
        job_info = job_info.get("jobInfo", job_info)
        job_id = job_info.get("id") or job_info.get("jobId")
    else:
        job_id = (payload.get("data") or {}).get("jobId")
        if not job_id:
            raise SfCommandError(
                f"Command failed with no recoverable job id (exit {returncode}): {' '.join(cmd)}\n"
                f"STDERR:\n{err}\nSTDOUT:\n{out}"
            )
        job_info = {}

    success_path, failed_path = fetch_bulk_results(org_alias, job_id, output_dir=output_dir)

    # Prefer counting actual rows in the result CSVs over the job JSON's
    # count fields - verifiably accurate regardless of what the JSON shape
    # turns out to be (this has already been observed to report 0/0 even
    # when a real job completed successfully, on an earlier CLI version).
    file_succeeded = _count_csv_data_rows(success_path)
    file_failed = _count_csv_data_rows(failed_path)

    if file_succeeded is not None or file_failed is not None:
        succeeded = file_succeeded or 0
        failed = file_failed or 0
        processed = succeeded + failed
    else:
        processed = int(job_info.get("processedRecords", job_info.get("numberRecordsProcessed", 0)))
        failed = int(job_info.get("failedRecords", job_info.get("numberRecordsFailed", 0)))
        succeeded = int(job_info.get("successfulRecords", processed - failed))

    return BulkJobResult(job_id, processed, succeeded, failed, success_path, failed_path)


def bulk_insert(org_alias: str, sobject: str, csv_path: str, wait_minutes: int = 10,
                 output_dir: str = "output") -> BulkJobResult:
    """Runs `sf data import bulk` and blocks (via --wait) until the job
    finishes. `sf data insert bulk` does not exist in current Salesforce CLI
    versions - `sf data import bulk` is the correct command for a plain
    insert (no external ID / upsert key needed)."""
    return _run_bulk_job([
        "sf", "data", "import", "bulk",
        "--sobject", sobject,
        "--file", csv_path,
        "--target-org", org_alias,
        "--wait", str(wait_minutes),
        "--json",
    ], org_alias, output_dir)


def bulk_upsert(org_alias: str, sobject: str, csv_path: str, external_id_field: str,
                 wait_minutes: int = 10, output_dir: str = "output") -> BulkJobResult:
    """Runs `sf data upsert bulk --external-id <field>`. Used directly for
    real upserts (Users, matched on Username), and indirectly by
    bulk_update() below (matched on the standard Id field)."""
    return _run_bulk_job([
        "sf", "data", "upsert", "bulk",
        "--sobject", sobject,
        "--file", csv_path,
        "--external-id", external_id_field,
        "--target-org", org_alias,
        "--wait", str(wait_minutes),
        "--json",
    ], org_alias, output_dir)


def bulk_upsert_chunked(org_alias: str, sobject: str, csv_path: str, external_id_field: str,
                         chunk_size: int, wait_minutes: int = 10,
                         output_dir: str = "output") -> BulkJobResult:
    """Same as bulk_upsert, but splits csv_path into chunk_size-row pieces
    and runs one Bulk API job per chunk, then merges every chunk's
    success/failed CSVs into one combined pair of report files.

    Bulk API 2.0 gives callers no control over its own internal batch size,
    and this org's UserPermissionsTrigger isn't bulk-safe past ~100-200
    records/transaction (loops per-record instead of using bulk DML/SOQL) -
    confirmed in practice: a single unchunked upsert of the full Users CSV
    failed EVERY row with "Too many SOQL queries: 201" once enough rows got
    past an earlier, unrelated DUPLICATE_USERNAME problem to actually reach
    the trigger. deactivate_users.py already works around this identical
    limit the same way, at the same chunk size (25) - see its own
    CHUNK_SIZE comment for the exact governor-limit numbers behind that
    choice; this is that same fix, generalized so any upsert can use it.
    """
    with open(csv_path, newline="", encoding="utf-8") as f:
        reader = csv.reader(f)
        header = next(reader)
        rows = list(reader)

    os.makedirs(output_dir, exist_ok=True)
    base = os.path.splitext(os.path.basename(csv_path))[0]
    total_succeeded = total_failed = total_processed = 0
    success_header = failed_header = None
    success_rows: list[list[str]] = []
    failed_rows: list[list[str]] = []
    last_job_id = None

    for i in range(0, len(rows), chunk_size):
        chunk = rows[i:i + chunk_size]
        chunk_num = i // chunk_size + 1
        chunk_path = f"{output_dir}/{base}_chunk{chunk_num}.csv"
        with open(chunk_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(header)
            writer.writerows(chunk)

        job = bulk_upsert(org_alias, sobject, chunk_path, external_id_field,
                           wait_minutes=wait_minutes, output_dir=output_dir)
        last_job_id = job.job_id or last_job_id
        total_succeeded += job.succeeded
        total_failed += job.failed
        total_processed += job.processed

        for path, header_slot, rows_slot in (
            (job.success_records_path, "success_header", success_rows),
            (job.failed_records_path, "failed_header", failed_rows),
        ):
            if path and os.path.exists(path):
                with open(path, newline="", encoding="utf-8", errors="replace") as f:
                    r = csv.reader(f)
                    h = next(r, None)
                    if h is not None:
                        if header_slot == "success_header" and success_header is None:
                            success_header = h
                        elif header_slot == "failed_header" and failed_header is None:
                            failed_header = h
                    rows_slot.extend(r)

    merged_success_path = merged_failed_path = None
    if success_rows and success_header is not None:
        merged_success_path = f"{output_dir}/{base}-success-records.csv"
        with open(merged_success_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(success_header)
            writer.writerows(success_rows)
    if failed_rows and failed_header is not None:
        merged_failed_path = f"{output_dir}/{base}-failed-records.csv"
        with open(merged_failed_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(failed_header)
            writer.writerows(failed_rows)

    return BulkJobResult(last_job_id, total_processed, total_succeeded, total_failed,
                          merged_success_path, merged_failed_path)


def bulk_update(org_alias: str, sobject: str, csv_path: str, wait_minutes: int = 10,
                 output_dir: str = "output") -> BulkJobResult:
    """Updates existing records. There is NO separate `sf data update bulk`
    command in current Salesforce CLI versions (confirmed absent from the
    official CLI command reference) - the documented way to do a plain
    update via Bulk API 2.0 is `sf data upsert bulk --external-id Id`,
    using Salesforce's own standard Id field as the match key. The input
    CSV must contain a real `Id` column with each row's actual record Id."""
    return bulk_upsert(org_alias, sobject, csv_path, external_id_field="Id",
                        wait_minutes=wait_minutes, output_dir=output_dir)


def _count_csv_data_rows(path: Optional[str]) -> Optional[int]:
    """Counts data rows (excluding header) in a CSV file, if it exists and
    is readable. Returns None if the path is None or the file can't be read
    - callers treat None as "unknown", not "zero"."""
    if not path or not os.path.exists(path):
        return None
    try:
        with open(path, newline="", encoding="utf-8", errors="replace") as f:
            reader = csv.reader(f)
            rows = list(reader)
        return max(len(rows) - 1, 0)
    except Exception:
        return None


def fetch_bulk_results(org_alias: str, job_id: str, output_dir: str = "output") -> tuple[Optional[str], Optional[str]]:
    """Fetches the per-row success/failure CSVs for a completed bulk job via
    `sf data bulk results` - a real, documented command
    (https://developer.salesforce.com/docs/platform/salesforce-cli-reference/guide/cli_reference_data_bulk_results.html).

    `sf data bulk results` has no flag to choose where it writes the CSVs -
    it always drops them in the current working directory. Running the
    command with cwd=output_dir keeps them where the rest of this tool's
    generated artifacts already live and are already .gitignored, rather
    than needing to relocate them after the fact.

    The exact JSON key names for the file paths aren't documented, so this
    defensively checks several plausible key names and falls back to
    scanning the raw stdout for "*.csv" paths - either way it returns
    (None, None) rather than raising, so a quirk here never crashes a load
    that has already completed successfully."""
    os.makedirs(output_dir, exist_ok=True)
    try:
        out = _run(
            ["sf", "data", "bulk", "results", "--job-id", job_id, "--target-org", org_alias, "--json"],
            cwd=output_dir,
        )
    except SfCommandError:
        return None, None

    result = None
    try:
        result = json.loads(out).get("result", {})
    except json.JSONDecodeError:
        pass

    def _in_output_dir(filename: Optional[str]) -> Optional[str]:
        return os.path.join(output_dir, filename) if filename else None

    if isinstance(result, dict):
        for success_key, failed_key in [
            ("successFilePath", "failedFilePath"),
            ("successRecordsFile", "failedRecordsFile"),
            ("successFile", "failedFile"),
        ]:
            if success_key in result:
                return _in_output_dir(result.get(success_key)), _in_output_dir(result.get(failed_key))

    csv_paths = re.findall(r"[^\s\"']+\.csv", out)
    success_paths = [p for p in csv_paths if "success" in p.lower()]
    failed_paths = [p for p in csv_paths if "fail" in p.lower()]
    return (_in_output_dir(success_paths[0]) if success_paths else None,
            _in_output_dir(failed_paths[0]) if failed_paths else None)


def query(org_alias: str, soql: str, use_tooling_api: bool = False) -> list[dict]:
    """Run a SOQL query and return rows as list of dicts. Uses the global
    --json flag (not --result-format json) - Salesforce's own docs state
    these produce different output shapes and that --json overrides
    --result-format."""
    cmd = ["sf", "data", "query", "--query", soql, "--target-org", org_alias, "--json"]
    if use_tooling_api:
        cmd.append("--use-tooling-api")
    out = _run(cmd)
    return json.loads(out)["result"]["records"]


def composite_tree_insert_batch(org_alias: str, sobject: str, records: list[dict],
                                 output_dir: str = "output") -> dict:
    """Inserts up to 200 records in ONE call via the Composite/SObject Tree
    API - the CLI has no dedicated wrapper for this (confirmed: `sf data`
    only exposes create/import/upsert/update/delete, all Bulk-API-backed),
    so this goes through `sf api request rest`, the CLI's generic
    authenticated-REST-call command, keeping this module as the only place
    that touches the network, same as everywhere else in this file.

    Each record dict must already include an "attributes" key
    ({"type": sobject, "referenceId": "..."}) plus every other field to set.
    Salesforce echoes back the real new Id paired with that referenceId in
    the SAME response - no separate query or manual step needed afterward,
    which is what makes it possible to fully automate objects (Account,
    Case, YTS_Transition_Plan) that have no safe bookkeeping field to build
    an OLD_ID -> new Id reference table from otherwise (see
    mapping_config.yaml's top-of-file comment).

    Caller must chunk to <=200 records - that's a hard Salesforce Composite
    Tree API limit, not configurable here.

    Returns the raw parsed JSON response:
      {"hasErrors": bool, "results": [
          {"referenceId": ..., "id": ...}                    (success), or
          {"referenceId": ..., "errors": [{"message": ...}]} (failure)
      ...]}
    """
    api_version = check_org_connection(org_alias)["apiVersion"]
    os.makedirs(output_dir, exist_ok=True)
    body_path = os.path.join(output_dir, f"_composite_tree_request_{sobject}.json")
    with open(body_path, "w", encoding="utf-8") as f:
        json.dump({"records": records}, f)

    # Uses _run_raw (not _run) deliberately: confirmed in practice that
    # `sf api request rest` exits non-zero whenever the response body has
    # "hasErrors": true - even though that JSON is a completely valid,
    # useful partial-failure response (e.g. one real custom validation
    # error among many successes), the exact same "partial failure isn't a
    # command failure" situation _run_bulk_job already handles for the Bulk
    # API. Raising here on non-zero exit would crash the whole deploy on
    # the very first real per-record validation error instead of reporting
    # it and moving on, same failure mode this pattern already fixed once.
    returncode, out, err = _run_raw([
        "sf", "api", "request", "rest",
        f"services/data/v{api_version}/composite/tree/{sobject}",
        "--target-org", org_alias,
        "-X", "POST",
        "-b", f"@{body_path}",
    ])
    try:
        return json.loads(out)
    except json.JSONDecodeError:
        raise SfCommandError(
            f"Composite Tree API returned non-JSON output (exit {returncode}): {out}\n"
            f"STDERR:\n{err}"
        )


def get_active_flow_version_id(org_alias: str, flow_api_name: str) -> Optional[str]:
    """Looks up the Id of whichever Flow version is CURRENTLY active for this
    Flow, via the Tooling API. Returns None if the Flow has no active
    version, doesn't exist by that name, or flow_api_name is falsy."""
    if not flow_api_name:
        return None
    records = query(
        org_alias,
        f"SELECT ActiveVersionId FROM FlowDefinition WHERE DeveloperName = '{flow_api_name}'",
        use_tooling_api=True,
    )
    if not records:
        return None
    return records[0].get("ActiveVersionId")
