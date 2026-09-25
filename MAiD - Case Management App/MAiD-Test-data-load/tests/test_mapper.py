"""
Offline unit tests for scripts/mapper.py.

These run with zero Salesforce/network dependency - `pytest tests/ -v` should
be runnable in CI on every PR, before anyone touches a real org. This is the
first validation layer described in the process (cheapest/fastest).
"""
import os
import sys
import pandas as pd
import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))
import mapper  # noqa: E402

FIXTURES = os.path.join(os.path.dirname(__file__), "fixtures")


def test_build_lookup_map_basic():
    export_df = pd.DataFrame({"Id": ["001A", "001B", "001C"], "College_ID__pc": ["25698", "25699", "25700"]})
    m = mapper.build_lookup_map(export_df, "College_ID__pc")
    assert m == {"25698": "001A", "25699": "001B", "25700": "001C"}


def test_build_lookup_map_raises_on_duplicate_key():
    export_df = pd.DataFrame({"Id": ["001A", "001B"], "College_ID__pc": ["25698", "25698"]})
    with pytest.raises(ValueError, match="Duplicate"):
        mapper.build_lookup_map(export_df, "College_ID__pc")


def test_build_lookup_map_returns_empty_dict_for_columnless_dataframe():
    # pd.DataFrame([]) - what you get from an org query that returned zero
    # rows - has no columns at all, not just zero rows.
    export_df = pd.DataFrame([])
    assert mapper.build_lookup_map(export_df, "College_ID__pc") == {}


def test_apply_lookups_replaces_stale_id_with_new_id():
    df = pd.DataFrame({
        "Case__c": ["500OLD_ORG_ID_1", "500OLD_ORG_ID_2"],
        "PHN__c": ["8000000001", "8000000002"],
    })
    case_map = {"8000000001": "500NEWORGID1", "8000000002": "500NEWORGID2"}
    lookups = [{"source_column": "PHN__c", "target_column": "Case__c", "map": "case"}]

    result = mapper.apply_lookups(df, lookups, {"case": case_map})

    assert list(result.dataframe["Case__c"]) == ["500NEWORGID1", "500NEWORGID2"]
    assert result.matched_rows == 2
    assert result.unmatched_rows == []


def test_apply_lookups_flags_unmatched_without_dropping_row():
    df = pd.DataFrame({
        "Case__c": ["500OLD_ORG_ID_1", "500OLD_ORG_ID_2"],
        "PHN__c": ["8000000001", "9999999999"],  # second PHN doesn't exist in case_map
    })
    case_map = {"8000000001": "500NEWORGID1"}
    lookups = [{"source_column": "PHN__c", "target_column": "Case__c", "map": "case"}]

    result = mapper.apply_lookups(df, lookups, {"case": case_map})

    assert result.total_rows == 2
    assert result.matched_rows == 1
    assert len(result.unmatched_rows) == 1
    assert result.unmatched_rows[0]["source_value"] == "9999999999"
    # row is NOT dropped from the dataframe - just blanked, so it's still visible/inspectable
    assert len(result.dataframe) == 2
    assert result.dataframe.loc[1, "Case__c"] == ""


def test_apply_lookups_empty_join_key_is_flagged():
    df = pd.DataFrame({"Case__c": ["500OLD"], "PHN__c": [""]})
    lookups = [{"source_column": "PHN__c", "target_column": "Case__c", "map": "case"}]
    result = mapper.apply_lookups(df, lookups, {"case": {}})
    assert result.unmatched_rows[0]["reason"] == "empty join key"


def test_apply_lookups_missing_source_column_raises():
    df = pd.DataFrame({"Case__c": ["500OLD"]})
    lookups = [{"source_column": "PHN__c", "target_column": "Case__c", "map": "case"}]
    with pytest.raises(KeyError, match="PHN__c"):
        mapper.apply_lookups(df, lookups, {"case": {}})


def test_drop_owner_id_removes_column_if_present():
    df = pd.DataFrame({"Name": ["a", "b"], "OwnerId": ["005OLD_ORG_1", "005OLD_ORG_2"]})
    out = mapper.drop_owner_id(df)
    assert list(out.columns) == ["Name"]


def test_drop_owner_id_is_a_noop_if_absent():
    df = pd.DataFrame({"Name": ["a", "b"]})
    out = mapper.drop_owner_id(df)
    assert list(out.columns) == ["Name"]


def test_normalize_us_dates_converts_bare_us_dates_to_iso():
    df = pd.DataFrame({
        "Patient_Date_of_Birth__c": ["5/29/1937", "12/24/2022"],
        "DateTime_Practitioner_signed__c": ["2022-10-26T00:00:00.000Z", ""],
        "Active__c": ["TRUE", "FALSE"],
    })
    out = mapper.normalize_us_dates(df)
    assert list(out["Patient_Date_of_Birth__c"]) == ["1937-05-29", "2022-12-24"]
    # already-ISO datetimes, booleans, and blanks must pass through untouched
    assert list(out["DateTime_Practitioner_signed__c"]) == ["2022-10-26T00:00:00.000Z", ""]
    assert list(out["Active__c"]) == ["TRUE", "FALSE"]


def test_normalize_us_dates_pads_single_digit_month_and_day():
    df = pd.DataFrame({"Date_Received__c": ["1/5/2023"]})
    out = mapper.normalize_us_dates(df)
    assert list(out["Date_Received__c"]) == ["2023-01-05"]


def test_analyze_date_column_flags_values_normalize_us_dates_cant_fix():
    convertible, unrecognized = mapper.analyze_date_column(["2024-01-01", "5/29/1937", "not-a-date", ""])
    assert convertible == 1
    assert unrecognized == ["not-a-date"]


def test_drop_noncreateable_columns_removes_formula_and_system_fields():
    df = pd.DataFrame({
        "PHN__c": ["8000000001"],
        "College_ID__c": ["25698"],  # formula field on Case - not createable
        "SystemModstamp": ["2024-01-01T00:00:00.000Z"],
    })
    field_meta = {
        "PHN__c": {"type": "string", "createable": True},
        "College_ID__c": {"type": "string", "createable": False},
        "SystemModstamp": {"type": "datetime", "createable": False},
    }
    out, dropped = mapper.drop_noncreateable_columns(df, field_meta)
    assert sorted(dropped) == ["College_ID__c", "SystemModstamp"]
    assert list(out.columns) == ["PHN__c"]


def test_drop_noncreateable_columns_leaves_unknown_columns_alone():
    df = pd.DataFrame({"Some_Helper_Column": ["x"]})
    out, dropped = mapper.drop_noncreateable_columns(df, {})
    assert dropped == []
    assert list(out.columns) == ["Some_Helper_Column"]


# --------------------------------------------------------------------------
# Integration-style tests against real (trimmed) sample data, proving the
# actual join keys in the provided CSVs behave as expected.
# --------------------------------------------------------------------------
def test_real_account_college_id_is_unique():
    df = mapper.load_csv(os.path.join(FIXTURES, "Account.csv"))
    assert df["College_ID__pc"].is_unique


def test_real_case_to_account_join_matches_where_expected():
    account_df = mapper.load_csv(os.path.join(FIXTURES, "Account.csv"))
    case_df = mapper.load_csv(os.path.join(FIXTURES, "Case.csv"))

    # Simulate what a post-insert org export looks like: real Salesforce Ids
    # (here just synthetic stand-ins) keyed by College_ID__pc - this is what
    # sf_runner.query() would return in the real deploy run.
    simulated_export = pd.DataFrame({
        "Id": [f"001NEW{i}" for i in range(len(account_df))],
        "College_ID__pc": account_df["College_ID__pc"],
    })
    account_map = mapper.build_lookup_map(simulated_export, "College_ID__pc")
    lookups = [{"source_column": "College_ID__c", "target_column": "Practitioner_Name__c", "map": "account"}]

    result = mapper.apply_lookups(case_df, lookups, {"account": account_map})

    # In the trimmed 5-row fixture, only College_ID 25699 overlaps between
    # Account and Case - proving the join mechanics work correctly on real
    # data, including the "not everything matches in a small sample" case.
    assert result.total_rows == 5
    assert result.matched_rows >= 1
    matched_row = result.dataframe[result.dataframe["College_ID__c"] == "25699"].iloc[0]
    assert matched_row["Practitioner_Name__c"] == account_map["25699"]


def test_real_form_1632_to_case_join():
    case_df = mapper.load_csv(os.path.join(FIXTURES, "Case.csv"))
    form_df = mapper.load_csv(os.path.join(FIXTURES, "Form_1632.csv"))

    # Simulate the post-insert Case export (Id + PHN__c) the same way deploy does.
    simulated_export = pd.DataFrame({
        "Id": [f"500NEW{i}" for i in range(len(case_df))],
        "PHN__c": case_df["PHN__c"],
    })
    case_map = mapper.build_lookup_map(simulated_export, "PHN__c")
    lookups = [{"source_column": "PHN__c", "target_column": "Case__c", "map": "case"}]

    result = mapper.apply_lookups(form_df, lookups, {"case": case_map})

    matched = form_df["PHN__c"].isin(case_map.keys()).sum()
    assert result.matched_rows == matched
    # every matched row's Case__c must now be the NEW id, never the stale org id
    for _, row in result.dataframe.iterrows():
        if row["Case__c"]:
            assert not row["Case__c"].startswith("500Aw")  # old-org id prefix seen in source data
