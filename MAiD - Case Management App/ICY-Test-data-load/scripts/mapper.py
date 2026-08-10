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
from typing import Dict, List, Optional


@dataclass
class LookupResult:
    dataframe: pd.DataFrame
    total_rows: int
    matched_rows: int
    unmatched_rows: List[dict]  # rows where the join key had no match - surfaced, never silently dropped


def load_csv(path: str) -> pd.DataFrame:
    # keep everything as string - these are Salesforce IDs/keys, never do numeric coercion
    try:
        return pd.read_csv(path, dtype=str, keep_default_na=False, encoding="utf-8")
    except UnicodeDecodeError:
        # Some exports (seen in practice: a Windows-1252-encoded name with an
        # accented character) aren't valid UTF-8. cp1252 covers the common
        # Windows export case; errors="replace" as a last resort ensures a
        # single bad byte never blocks the whole file from loading.
        try:
            return pd.read_csv(path, dtype=str, keep_default_na=False, encoding="cp1252")
        except UnicodeDecodeError:
            return pd.read_csv(path, dtype=str, keep_default_na=False, encoding="utf-8", encoding_errors="replace")


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

        # The source data often still carries its own raw, stale copy of the
        # target field (e.g. a literal CASE__C column sitting alongside the
        # OLD_CASE bookkeeping column this lookup resolves from) - Salesforce
        # Bulk API matches CSV headers to field names case-insensitively, so
        # if that stale column survives under different casing (CASE__C vs
        # Case__c) the load fails with "Duplicate field" once both reach the
        # CSV, even though pandas treats them as distinct columns. Drop any
        # such pre-existing collision before writing the resolved value.
        stale_collisions = [c for c in out.columns
                             if c != src_col and c != tgt_col and c.lower() == tgt_col.lower()]
        if stale_collisions:
            out = out.drop(columns=stale_collisions)

        out[tgt_col] = resolved.where(~this_miss, other="")  # blank out rather than keep stale foreign-org id

        if lk.get("drop_source") and src_col != tgt_col:
            columns_to_drop.append(src_col)

    if columns_to_drop:
        out = out.drop(columns=columns_to_drop)

    matched_rows = int((~row_had_miss).sum())
    return LookupResult(dataframe=out, total_rows=total_rows, matched_rows=matched_rows, unmatched_rows=unmatched_rows)


def rename_columns(df: pd.DataFrame, rename_map: Dict[str, str]) -> pd.DataFrame:
    """Renames CSV headers to real Salesforce field API names before insert.

    Some ICY source exports use all-caps or otherwise non-canonical header
    names (e.g. `CONTACT_PERSON_FIRST_NAME__C` instead of the real
    `Contact_Person_First_Name__c`) - this was previously handled by loading
    a Data Loader .sdl mapping file by hand. This replicates that mapping
    directly from mapping_config.yaml instead. Only renames columns present
    in both the dataframe and the map; anything not listed is left as-is.
    """
    applicable = {k: v for k, v in rename_map.items() if k in df.columns}
    return df.rename(columns=applicable)


def remap_values(df: pd.DataFrame, remap_spec: Dict[str, Dict[str, str]]) -> pd.DataFrame:
    """Rewrites specific cell values within named columns - for stale
    picklist values that existed in the OLD org but were renamed/consolidated
    in the target org (e.g. a bare "Other" that's now "Other Phone"), where
    the fix is a business-data value decision, not a mechanical column
    transform. Only remaps columns actually present in df; any value not
    listed in that column's remap dict is left untouched.

    remap_spec: {column_name: {old_value: new_value, ...}, ...}
    """
    out = df.copy()
    for col, value_map in remap_spec.items():
        if col in out.columns:
            out[col] = out[col].replace(value_map)
    return out


def build_scoped_query(sobject: str, key_field: str, keys: list, id_field: str = "Id") -> str:
    """Builds a SOQL query scoped to ONLY the given key values, instead of
    pulling every record of the object.

    A blanket "SELECT Id, College_ID__pc FROM Account" pulls every Account
    already in the org, including pre-existing records with a blank or
    unrelated College_ID__pc that have nothing to do with this load - which
    is exactly what caused a "Duplicate ... [nan]" crash in practice (a
    sandbox with 6 pre-existing blank-key Accounts, confirmed live). Scoping
    to `WHERE key_field IN (...)` means the export only ever returns records
    this load actually cares about.

    If `keys` is empty, returns a query guaranteed to return zero rows
    rather than silently falling back to an unscoped (and therefore unsafe)
    query.
    """
    escaped = sorted({k.replace("'", "\\'") for k in keys if k})
    if not escaped:
        return f"SELECT {id_field}, {key_field} FROM {sobject} WHERE {key_field} = null LIMIT 0"
    quoted = ",".join(f"'{k}'" for k in escaped)
    return f"SELECT {id_field}, {key_field} FROM {sobject} WHERE {key_field} IN ({quoted})"


_US_DATE_RE = re.compile(r"^(\d{1,2})/(\d{1,2})/(\d{4})$")


def normalize_us_dates(df: pd.DataFrame) -> pd.DataFrame:
    """Rewrites any cell that looks like a bare US-style date - "12/19/2023",
    "3/6/2024" - into Salesforce's required ISO format ("2023-12-19").

    Several ICY source CSVs export plain xsd:date fields this way (e.g.
    ICY_DATE_OF_REFERRAL__C, ICY_START_DATE__C) - the Bulk API rejects the
    entire row with "... is not a valid value for the type xsd:date" for
    anything other than YYYY-MM-DD. Datetime fields are already ISO in these
    exports (e.g. "2024-06-11T20:23:53.000Z") and don't match this pattern,
    and neither do booleans, free text, or blanks, so this is safe to run
    over every column rather than needing a hardcoded list of date column
    names per object (which would have to be kept in sync across all ~13
    ICY objects as fields change)."""
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
    neither - something that would still make the Bulk API reject that row
    after normalization runs (e.g. a truncated year or genuinely malformed
    data).

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


def drop_noncreateable_columns(df: pd.DataFrame, field_meta: Dict[str, dict],
                                protect_columns: Optional[set] = None,
                                flag: str = "createable") -> tuple[pd.DataFrame, List[str]]:
    """Drops any column that maps to a real org field the Bulk API won't let
    us set on insert/upsert - formula/rollup fields (calculated), system
    audit fields (IsDeleted, SystemModstamp, CreatedDate...), or anything
    restricted by field-level security for the running user. Salesforce
    rejects the ENTIRE row if even one such field is present
    ("INVALID_FIELD_FOR_INSERT_UPDATE: Unable to create/update fields: ..."),
    so these have to come out before insert rather than be left for
    Salesforce to reject. ICY's ~13 objects each have their own set of
    formula/system fields, so this uses the org's own field metadata
    (`createable`) instead of a hardcoded per-object list.

    field_meta: dict of field API name -> {"type": ..., "createable": ...},
    as returned by sf_runner.describe_sobject_fields(). Columns that don't
    match any real field name in field_meta are left alone here - this only
    acts on columns positively confirmed to be non-createable.

    Returns (dataframe with those columns removed, list of column names
    dropped) so the caller can report what was removed.

    Matching is case-INSENSITIVE against field_meta's keys: raw ICY source
    CSVs use ALL-CAPS/Data-Loader-style headers (e.g. NAME, PRIMARYCONTACT__C)
    that never exactly match the org's real Title_Case field names, but
    Salesforce's own Bulk API matches CSV headers to fields case-insensitively
    regardless - an exact-case check here would silently let genuinely
    non-createable fields (formula Name fields, system audit fields, etc.)
    slip through and hard-fail the whole row at the real Bulk API load,
    exactly the failure mode this function exists to prevent.

    protect_columns: exact column names to never drop regardless of field
    metadata - needed because bookkeeping-only columns (export_key_field,
    match_key_column) can coincidentally case-collide with a REAL
    non-createable field name (confirmed in practice: Intake's own identity
    column is literally named "ID", which case-insensitively matches
    Salesforce's standard "Id" field - always non-createable - so without
    this protection, the bookkeeping column itself gets silently stripped
    out right before an `update` stage needs it to build the match-key
    mapping, crashing with "KeyError: 'ID'").

    flag: which field-metadata flag to check - "createable" (default, for
    insert/upsert stages) or "updateable" (for `update` stages). These
    genuinely diverge for audit fields: CreatedDate/CreatedById/
    LastModifiedDate/LastModifiedById can be createable=True (e.g. a "Set
    Audit Fields upon Record Creation" permission enabling them at insert
    time) while still being updateable=False (Salesforce never allows
    changing them after the record exists) - confirmed in practice: an
    insert stage succeeded sending these, then the matching update pass on
    the same object failed with "Unable to create/update fields:
    CreatedDate, LastModifiedDate" for every single row.
    """
    protect = set(protect_columns or [])
    field_meta_lower = {name.lower(): meta for name, meta in field_meta.items()}
    to_drop = [c for c in df.columns
               if c not in protect and c.lower() in field_meta_lower
               and not field_meta_lower[c.lower()].get(flag, True)]
    if not to_drop:
        return df, []
    return df.drop(columns=to_drop), to_drop


def drop_rows_by_username_domain(df: pd.DataFrame, domains: list[str],
                                  username_column: str = "USERNAME") -> tuple[pd.DataFrame, int]:
    """Drops rows whose Username's domain (the part after "@") ends with
    any of `domains` (case-insensitive) - e.g. "chatter.salesforce.com" for
    Salesforce's own auto-generated Chatter-Free identities
    (`chatty.<orgid>.<hash>@chatter.salesforce.com`).

    These aren't real test personas - they're a system-generated artifact of
    the OLD org, tied to that org's literal Id. Renaming one via
    ensure_username_domain_suffix would "succeed" (the string becomes
    unique) but would load a meaningless placeholder account rather than a
    genuine ICY persona, so they're excluded entirely instead.

    Returns (dataframe, count of rows dropped).
    """
    if username_column not in df.columns or not domains:
        return df, 0
    domains_lower = tuple(d.lower() for d in domains)
    usernames = df[username_column].fillna("")
    domain_part = usernames.apply(lambda u: u.rsplit("@", 1)[-1].lower() if "@" in u else "")
    drop_mask = domain_part.apply(lambda d: d.endswith(domains_lower))
    dropped = int(drop_mask.sum())
    if not dropped:
        return df, 0
    return df[~drop_mask].reset_index(drop=True), dropped


def ensure_username_domain_suffix(df: pd.DataFrame, suffix: str,
                                   username_column: str = "USERNAME") -> tuple[pd.DataFrame, int]:
    """Appends this org's real sandbox suffix (e.g. "sosehfdv") to every
    Username that doesn't already end with it, guaranteeing every row is
    unique to THIS org regardless of what stale domain it arrived with.

    Source CSVs are static exports that can carry usernames from ANY number
    of other real environments - production (`...@gov.bc.ca.bcmohmaid`),
    a different sandbox (`...@moh.com.maiduat.fc`), even Salesforce's own
    auto-generated Chatter-Free identities (`chatty.<orgid>...@chatter.
    salesforce.com`). Salesforce enforces username uniqueness GLOBALLY
    across every Salesforce org, not just the one being deployed to, so
    loading any of these as-is fails with DUPLICATE_USERNAME - the real
    owner of that exact string already exists somewhere else.

    Earlier versions of this function replaced one specific known-bad
    token (e.g. "SOSEUAT") - that only ever covers a stale domain someone
    has already hit, and silently leaves any other one (production,
    Chatter-Free, a third sandbox, ...) to fail the same way. Unconditionally
    appending this org's suffix instead needs no enumeration and fixes every
    shape at once. Idempotent by design: a username that already ends with
    the suffix (e.g. a second run, or a persona already prepped for this
    exact org) is left untouched rather than double-suffixed - EXCEPT for
    casing, always forced to lowercase (see below), never left as-is.

    IMPORTANT - the whole result is lowercased, not just the appended
    suffix: Salesforce silently stores every new Username in lowercase
    regardless of the case submitted at insert time (confirmed in practice
    against a live org - a mixed-case source value like
    "charlotte@icySOSEUATpersona.com" came back as
    "charlotte@icysoseuatpersona.com" once queried back). An earlier version
    of this function preserved the source CSV's original casing and only
    lowercased the appended suffix - harmless on the very first run (a
    plain insert), but on every run after that, Salesforce's Bulk API
    upsert matches the external-id (Username) field case-SENSITIVELY, so
    resending the original mixed-case value no longer matches the
    already-lowercased stored record - it's treated as a new row to insert,
    which then fails with DUPLICATE_USERNAME against the (case-insensitive)
    uniqueness constraint on the very record it should have matched.
    Lowercasing everything up front means every run computes the exact same
    value Salesforce already has on file, so the upsert match always finds
    it.

    IMPORTANT: suffix must be the org's actual sandbox name as it appears in
    real existing usernames (e.g. queried from the admin user's own
    Username), NOT the --org CLI alias string - the alias is just a local
    nickname the operator chose at login time and is not guaranteed to
    match Salesforce's real internal sandbox name (confirmed in practice:
    alias "SOSEHFDEV" vs real suffix "sosehfdv" - close but not identical).
    Using the alias directly would create a new, still-wrong, differently
    -shaped duplicate instead of fixing the problem.

    Returns (dataframe, count of rows whose Username actually changed).
    """
    if username_column not in df.columns:
        return df, 0
    out = df.copy()
    marker = "." + suffix.lower()

    def fix(u):
        if not u:
            return u
        lowered = u.lower()
        return lowered if lowered.endswith(marker) else f"{lowered}{marker}"

    before = out[username_column]
    after = before.apply(fix)
    changed = int((before != after).sum())
    out[username_column] = after
    return out, changed


def build_composite_tree_records(df: pd.DataFrame, sobject: str, ref_id_column: str) -> List[dict]:
    """Converts a prepared dataframe into the record list shape the
    Composite/SObject Tree API expects: each row becomes a dict of
    {field: value} (blank strings omitted - Salesforce treats an explicit
    empty string differently from an absent field for some types, so
    omitting is safer than sending ""), tagged with an "attributes" key
    naming the target sobject and a referenceId (this row's ref_id_column
    value, typically OLD_ID) that Salesforce echoes back paired with the
    new real Id - see sf_runner.composite_tree_insert_batch for how that
    response gets used to build a reference table with no manual step.

    ref_id_column itself is excluded from the field payload - it's never a
    real Salesforce field, only the join key used to build the reference
    table afterward.
    """
    records = []
    for _, row in df.iterrows():
        fields = {k: v for k, v in row.items() if k != ref_id_column and v != ""}
        fields["attributes"] = {"type": sobject, "referenceId": row[ref_id_column]}
        records.append(fields)
    return records


def coerce_composite_tree_field_types(records: List[dict], field_meta: Dict[str, dict]) -> List[dict]:
    """The Composite/SObject Tree API is a strict JSON REST endpoint, unlike
    the CSV-based Bulk API used for every other insert/upsert/update in this
    tool - it rejects boolean/numeric fields sent as JSON strings (confirmed
    in practice: "Cannot deserialize instance of boolean from VALUE_STRING
    value FALSE") even though the exact same string value works fine via
    Bulk API's CSV upload. mapper.load_csv() deliberately keeps every column
    as a string (never numeric-coerced - these are mostly Ids/keys), so this
    converts just the fields the org's own field metadata says are
    boolean/numeric into their real JSON types before a composite_insert
    stage submits them. Field name matching is case-insensitive, same
    reasoning as drop_noncreateable_columns (raw CSV headers are ALL-CAPS,
    real field names are Title_Case, and they never exact-match).
    """
    field_meta_lower = {name.lower(): meta for name, meta in field_meta.items()}
    out = []
    for record in records:
        fixed = {}
        for key, value in record.items():
            if key == "attributes":
                fixed[key] = value
                continue
            meta = field_meta_lower.get(key.lower())
            ftype = meta.get("type") if meta else None
            if ftype == "boolean":
                fixed[key] = str(value).strip().lower() == "true"
            elif ftype == "int":
                fixed[key] = int(value)
            elif ftype in ("double", "currency", "percent"):
                fixed[key] = float(value)
            else:
                fixed[key] = value
        out.append(fixed)
    return out


def drop_owner_columns(df: pd.DataFrame) -> pd.DataFrame:
    """Drops any column that resolves to the standard OwnerId field,
    regardless of casing - ICY's source CSVs are inconsistent about this
    across objects (some use `OwnerId`, most use `OWNERID`, per-object).
    Any pre-existing owner value in these CSVs is from a different org and
    meaningless in the target org; when omitted, Salesforce defaults each
    new record's owner to whichever user is running the load. For the two
    objects (Case, Case_Member) that need a SPECIFIC "valid ICY User" rather
    than the default, mapping_config.yaml's `set_fields` re-adds a real
    OwnerId value AFTER this drop runs, so the two don't conflict."""
    to_drop = [c for c in df.columns if c.lower() == "ownerid"]
    return df.drop(columns=to_drop, errors="ignore")


def set_static_fields(df: pd.DataFrame, set_fields: Optional[Dict[str, str]]) -> pd.DataFrame:
    """Apply static field overrides (e.g. OwnerId, RecordTypeId) resolved
    from config/env/org query.

    Drops any pre-existing column that collides with the target name
    case-insensitively before setting it - same reasoning as the identical
    fix in apply_lookups(): the raw source CSV often already carries its
    own stale copy of the same field under different casing (e.g. a
    literal RECORDTYPEID column alongside a resolved RecordTypeId
    override), and Salesforce matches CSV headers to fields
    case-insensitively, so leaving both in place fails the real Bulk API
    load with "Duplicate field" even though pandas treats them as two
    distinct columns.
    """
    if not set_fields:
        return df
    out = df.copy()
    for col, val in set_fields.items():
        stale_collisions = [c for c in out.columns if c != col and c.lower() == col.lower()]
        if stale_collisions:
            out = out.drop(columns=stale_collisions)
        out[col] = val
    return out
