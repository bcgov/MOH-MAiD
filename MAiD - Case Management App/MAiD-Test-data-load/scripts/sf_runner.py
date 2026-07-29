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
import json
import os
import subprocess
import sys
import csv
import io
from dataclasses import dataclass
from typing import Optional


class SfCommandError(RuntimeError):
    pass


def _run_raw(cmd: list[str], cwd: Optional[str] = None) -> tuple[int, str, str]:
    """Runs cmd and returns (returncode, stdout, stderr) without raising,
    regardless of exit code - most callers want _run() below instead, which
    raises on failure. This exists for the one case (bulk_insert) where a
    non-zero exit doesn't actually mean "nothing useful happened" - see its
    docstring."""
    # On Windows, `sf` (and most npm-installed CLIs) are installed as .cmd
    # shims, not real .exe files. subprocess.run() with shell=False cannot
    # execute those directly (fails with "WinError 2: file not found" even
    # though the command works fine when typed manually). Routing through
    # the shell on Windows only fixes this; POSIX is unaffected either way.
    is_windows = os.name == "nt"
    # Also force UTF-8 decoding explicitly: with text=True alone, Windows
    # defaults to the system codepage (cp1252), which crashes on any
    # non-ASCII byte in sf's JSON output (e.g. a curly quote/em-dash in a
    # CSV field that gets echoed back). errors="replace" ensures a decoding
    # hiccup degrades to a placeholder character instead of crashing the
    # whole run.
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
    """Return a dict of field API name -> {"type": ..., "createable": ...}
    on an object. Used by `validate`/`deploy` to catch typos in
    mapping_config.yaml (via `col in fields` / `col not in fields` - dict
    membership checks keys, so this is a drop-in replacement for the bare
    set of names this used to return), to catch date-format problems in the
    source CSVs, and to drop formula/system/FLS-restricted columns the Bulk
    API would otherwise reject the whole row for."""
    out = _run(["sf", "sobject", "describe", "--sobject", sobject, "--target-org", org_alias, "--json"])
    data = json.loads(out)["result"]
    return {f["name"]: {"type": f["type"], "createable": f.get("createable", True)} for f in data.get("fields", [])}


@dataclass
class BulkJobResult:
    job_id: str
    processed: int
    succeeded: int
    failed: int
    success_records_path: Optional[str]
    failed_records_path: Optional[str]


def bulk_insert(org_alias: str, sobject: str, csv_path: str, wait_minutes: int = 10) -> BulkJobResult:
    """Runs `sf data import bulk` and blocks (via --wait) until the job finishes,
    then returns a structured summary. This is the command that gives us the
    "90 succeeded / 10 failed" behavior for free - Bulk API processes each row
    independently rather than failing the whole batch.

    NOTE: `sf data insert bulk` does not exist in current Salesforce CLI
    versions (@salesforce/cli 2.132.14 confirmed) - `sf data import bulk` is
    the correct command for a plain insert (no external ID / upsert key
    needed). `sf data upsert bulk` is the sibling command for upserts and
    requires --external-id, which doesn't apply here since we're always
    inserting brand-new records.

    NOTE: this CLI exits non-zero ("FailedRecordDetailsError") whenever ANY
    row in the batch fails to insert - even though the underlying Bulk API
    job completed normally and processed every other row just fine. Using
    _run() here (which raises on any non-zero exit) would turn a real,
    informative "36 succeeded / 4 failed" result into an unhandled crash
    that kills the whole deploy before Forms ever load. _run_raw() lets us
    inspect the response either way: on a clean exit it's the normal
    {"status": 0, "result": {...}} envelope; on this specific failure mode
    it's an error envelope that still carries "data": {"jobId": ...}, which
    is all fetch_bulk_results() below needs to pull the real per-row
    results."""
    returncode, out, err = _run_raw([
        "sf", "data", "import", "bulk",
        "--sobject", sobject,
        "--file", csv_path,
        "--target-org", org_alias,
        "--wait", str(wait_minutes),
        "--json",
    ])
    try:
        payload = json.loads(out)
    except json.JSONDecodeError:
        raise SfCommandError(
            f"sf data import bulk returned non-JSON output (exit {returncode}):\nSTDERR:\n{err}\nSTDOUT:\n{out}"
        )

    if payload.get("status") == 0:
        job_info = payload["result"]
        job_info = job_info.get("jobInfo", job_info)
        job_id = job_info.get("id") or job_info.get("jobId")
    else:
        job_id = (payload.get("data") or {}).get("jobId")
        if not job_id:
            raise SfCommandError(
                f"sf data import bulk failed with no recoverable job id (exit {returncode}):\n"
                f"STDERR:\n{err}\nSTDOUT:\n{out}"
            )
        job_info = {}

    success_path, failed_path = fetch_bulk_results(org_alias, job_id)

    # Prefer counting actual rows in the result CSVs over the job JSON's
    # numberRecordsProcessed/numberRecordsFailed fields - those field names
    # are a guess at this CLI version's exact output shape and have already
    # been observed to report 0/0 even when a real job completed
    # successfully. Counting the CSVs directly (each row = one record) is
    # verifiably accurate regardless of what the JSON actually looks like.
    file_succeeded = _count_csv_data_rows(success_path)
    file_failed = _count_csv_data_rows(failed_path)

    if file_succeeded is not None or file_failed is not None:
        succeeded = file_succeeded or 0
        failed = file_failed or 0
        processed = succeeded + failed
    else:
        # Fall back to the job JSON's own counts only if we couldn't read
        # either result file at all.
        processed = int(job_info.get("numberRecordsProcessed", 0))
        failed = int(job_info.get("numberRecordsFailed", 0))
        succeeded = processed - failed

    return BulkJobResult(job_id, processed, succeeded, failed, success_path, failed_path)


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
        return max(len(rows) - 1, 0)  # subtract header row
    except Exception:
        return None


def fetch_bulk_results(org_alias: str, job_id: str, output_dir: str = "output") -> tuple[Optional[str], Optional[str]]:
    """Fetches the per-row success/failure CSVs for a completed bulk job via
    `sf data bulk results` - confirmed as a real, documented command
    (https://developer.salesforce.com/docs/platform/salesforce-cli-reference/guide/cli_reference_data_bulk_results.html):
    "the output displays the names of the generated CSV-formatted files that
    contain the specific results for each ingested record." Uses --json for
    a consistent, parseable envelope like every other function in this file.

    `sf data bulk results` has no flag to choose where it writes the CSVs -
    it always drops them in the current working directory. Left alone, that
    means the job-id-named files land next to the script (not under
    output/), which isn't covered by .gitignore's `output/` or `data/*.csv`
    patterns even though the files contain the same sensitive record data.
    Running the command with cwd=output_dir keeps them where the rest of
    this tool's generated artifacts already live and are already ignored.

    The exact JSON key names for the file paths aren't documented on that
    page, so this defensively checks several plausible key names and falls
    back to scanning the raw (human-readable) stdout for "*.csv" paths if
    the JSON shape doesn't match what's expected - either way it returns
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

    # Fall back to scanning raw stdout text for "*.csv" paths, in case the
    # JSON shape differs from the above guesses but the file names are
    # still mentioned in the output somewhere.
    import re
    csv_paths = re.findall(r"[^\s\"']+\.csv", out)
    success_paths = [p for p in csv_paths if "success" in p.lower()]
    failed_paths = [p for p in csv_paths if "fail" in p.lower()]
    return (_in_output_dir(success_paths[0]) if success_paths else None,
            _in_output_dir(failed_paths[0]) if failed_paths else None)


def query(org_alias: str, soql: str, use_tooling_api: bool = False) -> list[dict]:
    """Run a SOQL query and return rows as list of dicts (used for the
    post-insert Account/Case export step, and for Tooling API lookups like
    FlowDefinition).

    Uses the global --json flag (not --result-format json) - Salesforce's
    own docs state these produce different output shapes and that --json
    overrides --result-format, so mixing them (as an earlier version of this
    function did) parses the wrong structure. --json wraps output in the
    standard {"status":.., "result": {...}} envelope, matching every other
    function in this file."""
    cmd = ["sf", "data", "query", "--query", soql, "--target-org", org_alias, "--json"]
    if use_tooling_api:
        cmd.append("--use-tooling-api")
    out = _run(cmd)
    return json.loads(out)["result"]["records"]


def get_active_flow_version_id(org_alias: str, flow_api_name: str) -> Optional[str]:
    """Looks up the Id of whichever Flow version is CURRENTLY active for this
    Flow, via the Tooling API. This is the specific version we must restore
    later - Salesforce Flows are versioned, and reactivating "some" version
    isn't equivalent to reactivating the one that was actually running
    before we touched it. Returns None if the Flow has no active version
    (e.g. it's already deactivated, or doesn't exist by that name)."""
    records = query(
        org_alias,
        f"SELECT ActiveVersionId FROM FlowDefinition WHERE DeveloperName = '{flow_api_name}'",
        use_tooling_api=True,
    )
    if not records:
        return None
    return records[0].get("ActiveVersionId")


def set_flow_version_status(org_alias: str, flow_version_id: str, status: str) -> None:
    """Sets a SPECIFIC Flow version's Status field ('Active' or 'Draft') via
    the Tooling API. Operating on the exact version Id (not "the Flow" in
    general) is what guarantees you restore precisely the version that was
    running before, regardless of how many versions/edits exist.

    NOTE: `deploy` no longer calls this automatically - Flow
    deactivation/reactivation is handled manually by design (this org hit an
    "InteractionDefinitionVersion" Tooling API error attempting it
    automatically). Kept here as a utility in case manual/scripted toggling
    via this function is useful outside the main deploy flow."""
    _run([
        "sf", "data", "update", "record",
        "--sobject", "Flow",
        "--record-id", flow_version_id,
        "--values", f"Status={status}",
        "--target-org", org_alias,
        "--use-tooling-api",
    ])
