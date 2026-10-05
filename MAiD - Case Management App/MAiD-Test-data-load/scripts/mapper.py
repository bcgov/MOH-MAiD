"""
mapper.py

Pure data-transformation logic for the MAiD test-data load.
No Salesforce/network calls live here on purpose - this module is fully
unit-testable offline with plain CSV fixtures (see tests/test_mapper.py).

Core idea:
  - After inserting Accounts/Cases into the target org, we export {new Id, key}
    pairs (key = College_ID for Account, PHN for Case).
  - build_lookup_map() turns that export into a dict: key -> new Id
  - apply_lookups() rewrites the specified columns in a Form/Case dataframe by
    joining on that dict, replacing whatever stale ID was in the source CSV.
"""
from __future__ import annotations
import re
import pandas as pd
from dataclasses import dataclass
from typing import Dict, List


@dataclass
class LookupResult:
    dataframe: pd.DataFrame
    total_rows: int
    matched_rows: int
    unmatched_rows: List[dict]  # rows where the join key had no match - surfaced, never silently dropped


def load_csv(path: str) -> pd.DataFrame:
    # keep everything as string - these are Salesforce IDs/keys, never do numeric coercion
    return pd.read_csv(path, dtype=str, keep_default_na=False)


_US_DATE_RE = re.compile(r"^(\d{1,2})/(\d{1,2})/(\d{4})$")


def normalize_us_dates(df: pd.DataFrame) -> pd.DataFrame:
    """Rewrites any cell that looks like a bare US-style date - "5/29/1937",
    "12/24/2022" - into Salesforce's required ISO format ("1937-05-29").

    The source CSVs export plain xsd:date fields this way, but the Bulk API
    rejects the entire row with "... is not a valid value for the type
    xsd:date" for anything other than YYYY-MM-DD - this is why a Case load
    failed 36/36 with every row citing Patient_Date_of_Birth__c. Datetime
    fields are already ISO in these exports (e.g.
    "2022-11-17T20:45:24.000Z") and don't match this pattern, and neither do
    booleans, free text, or blanks, so this is safe to run over every column
    rather than needing a hardcoded list of date column names (which would
    have to be kept in sync as new Form types are added)."""
    out = df.copy()

    def _convert(value: str) -> str:
        match = _US_DATE_RE.match(value) if value else None
        if not match:
            return value
        month, day, year = match.groups()
        return f"{year}-{int(month):02d}-{int(day):02d}"

    for col in out.columns:
        out[col] = out[col].map(_convert)
    return out


_ISO_DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
_ISO_DATETIME_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$")


def analyze_date_column(values) -> tuple[int, List[str]]:
    """Classifies every non-blank value in a column that maps to an org
    'date' field into one of three buckets: already ISO (fine as-is), a bare
    US-style date that normalize_us_dates() will fix before insert, or
    neither - something normalize_us_dates() can't recognize and that would
    still make the Bulk API reject that row after normalization runs (e.g.
    "Feb 1990", a truncated year, or genuinely malformed data).

    Returns (count of values that will be auto-converted, list of values in
    neither bucket). `validate` uses this to warn about the first and fail
    on the second before a real deploy attempt hits it."""
    convertible = 0
    unrecognized: List[str] = []
    for v in values:
        if not v:
            continue
        if _ISO_DATE_RE.match(v) or _ISO_DATETIME_RE.match(v):
            continue
        if _US_DATE_RE.match(v):
            convertible += 1
            continue
        unrecognized.append(v)
    return convertible, unrecognized


def drop_noncreateable_columns(df: pd.DataFrame, field_meta: Dict[str, dict]) -> tuple[pd.DataFrame, List[str]]:
    """Drops any column that maps to a real org field the Bulk API won't let
    us set on insert - formula/rollup fields (calculated), system audit
    fields (IsDeleted, SystemModstamp, CreatedDate...), or anything
    restricted by field-level security for the running user. Salesforce
    rejects the ENTIRE row if even one such field is present
    ("INVALID_FIELD_FOR_INSERT_UPDATE: Unable to create/update fields: ..."),
    so these have to come out before insert rather than be left for
    Salesforce to reject - and which fields these are varies per object (a
    hardcoded list would have to be re-derived for every Form), so this uses
    the org's own field metadata (`createable`) instead of guessing.

    field_meta: dict of field API name -> {"type": ..., "createable": ...},
    as returned by sf_runner.describe_sobject_fields(). Columns that don't
    match any real field name in field_meta are left alone here - this only
    acts on columns positively confirmed to be non-createable.

    Returns (dataframe with those columns removed, list of column names
    dropped) so the caller can report what was removed.
    """
    to_drop = [c for c in df.columns if c in field_meta and not field_meta[c].get("createable", True)]
    if not to_drop:
        return df, []
    return df.drop(columns=to_drop), to_drop


def build_lookup_map(export_df: pd.DataFrame, key_field: str, id_field: str = "Id") -> Dict[str, str]:
    """Turn an exported {Id, key_field} dataframe into a key -> Id dict.

    The export query (e.g. "SELECT Id, College_ID__pc FROM Account") pulls
    EVERY record of that object already in the org, not just the ones this
    run just inserted - a sandbox often has pre-existing records with a
    blank/null key field, completely unrelated to this load. A blank key can
    never be validly joined against anyway (apply_lookups already treats an
    empty source value as "no match" rather than looking it up), so multiple
    blank/null values are excluded here before the duplicate check, rather
    than treated as an ambiguous conflict.

    Raises only if a REAL (non-blank) key value is duplicated - that's a
    genuine ambiguity (e.g. two Accounts sharing the same College_ID__pc)
    and should stop the run rather than silently pick one.

    export_df can be empty (e.g. pd.DataFrame([]) when a query returned zero
    rows - nothing exists yet, and nothing failed) - in which case it may
    have no columns at all, so key_field is checked for first rather than
    indexed into directly, and an empty dict is returned rather than raising.
    """
    if key_field not in export_df.columns:
        return {}
    non_blank = export_df[export_df[key_field].notna() & (export_df[key_field] != "")]
    dupes = non_blank[non_blank.duplicated(subset=[key_field], keep=False)]
    if not dupes.empty:
        dup_keys = sorted(dupes[key_field].unique().tolist())
        raise ValueError(
            f"Duplicate '{key_field}' values found in org export, join would be ambiguous: {dup_keys}"
        )
    return dict(zip(non_blank[key_field], non_blank[id_field]))


def apply_lookups(df: pd.DataFrame, lookups: List[dict], lookup_maps: Dict[str, Dict[str, str]]) -> LookupResult:
    """Apply one or more column rewrites to df based on the lookups config.

    lookups: list of {source_column, target_column, map, drop_source?} dicts
        (from mapping_config.yaml). `drop_source: true` means the source
        column is a helper join-key only (e.g. "College ID" with a space -
        never a real Salesforce API field name) and must be removed from the
        dataframe after resolving, or the Bulk API will reject the whole
        load with "Field name not found" since it doesn't recognize it.
        Columns that ARE real fields in their own right (e.g. PHN__c,
        College_ID__c, which the object may legitimately store alongside
        the resolved lookup) should leave drop_source unset/false.
    lookup_maps: dict of map-name -> {key: new_id}, e.g. {"account": {...}, "case": {...}}

    Any row where ANY lookup fails to find a match is flagged in unmatched_rows
    (with the reason) but NOT dropped from the returned dataframe - the caller
    decides whether to exclude it before insert, matching the "don't silently
    drop data" principle.
    """
    out = df.copy()
    total_rows = len(out)
    unmatched_rows: List[dict] = []
    row_had_miss = pd.Series([False] * len(out), index=out.index)
    columns_to_drop: List[str] = []

    for lk in lookups:
        src_col = lk["source_column"]
        tgt_col = lk["target_column"]
        map_name = lk["map"]
        if src_col not in out.columns:
            raise KeyError(f"source_column '{src_col}' not found in input CSV columns: {list(out.columns)}")
        lookup_map = lookup_maps[map_name]

        resolved = out[src_col].map(lookup_map)
        miss_mask = resolved.isna() & (out[src_col] != "")
        # also treat truly empty key as a miss (nothing to join on)
        empty_mask = out[src_col] == ""
        this_miss = miss_mask | empty_mask

        for idx in out.index[this_miss]:
            unmatched_rows.append({
                "row_index": int(idx),
                "source_column": src_col,
                "source_value": out.at[idx, src_col],
                "target_column": tgt_col,
                "reason": "empty join key" if empty_mask[idx] else "no matching record in org export",
            })

        row_had_miss = row_had_miss | this_miss
        out[tgt_col] = resolved.where(~this_miss, other="")  # blank out rather than keep stale foreign-org id

        if lk.get("drop_source") and src_col != tgt_col:
            columns_to_drop.append(src_col)

    if columns_to_drop:
        out = out.drop(columns=columns_to_drop)

    matched_rows = int((~row_had_miss).sum())
    return LookupResult(dataframe=out, total_rows=total_rows, matched_rows=matched_rows, unmatched_rows=unmatched_rows)


def drop_owner_id(df: pd.DataFrame) -> pd.DataFrame:
    """Drops an OwnerId column if present. This load never sets OwnerId
    explicitly - when it's omitted, Salesforce defaults a new record's owner
    to whichever user is running the insert (the authenticated org
    connection), which is always the correct owner for a fresh sandbox load.
    The source CSVs sometimes carry a stale OwnerId from whatever org they
    were originally exported from (seen on Account, Case, and Form_1641);
    that value is meaningless in the target org and would otherwise be
    inserted as-is."""
    return df.drop(columns=["OwnerId"], errors="ignore")
