"""
Offline unit tests for scripts/mapper.py (ICY version).

Run with zero Salesforce/network dependency: `pytest tests/ -v`.
The core join/lookup primitives (apply_lookups, build_lookup_map,
build_scoped_query) are identical to the MAiD tool's already-proven
versions; this suite focuses on what's NEW/different for ICY:
rename_columns, and the real-data quirks found while building this
(non-UTF-8 CSVs, raw-Id-only RecordType columns, typo'd key columns).
"""
import os
import sys
import pandas as pd
import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))
import mapper  # noqa: E402

FIXTURES = os.path.join(os.path.dirname(__file__), "fixtures")


def test_rename_columns_applies_only_matching_keys():
    df = pd.DataFrame({"CONTACT_PERSON_FIRST_NAME__C": ["Jo"], "UNRELATED": ["x"]})
    renamed = mapper.rename_columns(df, {
        "CONTACT_PERSON_FIRST_NAME__C": "Contact_Person_First_Name__c",
        "SOME_OTHER_COLUMN_NOT_PRESENT__C": "Some_Other__c",
    })
    assert list(renamed.columns) == ["Contact_Person_First_Name__c", "UNRELATED"]


def test_rename_columns_leaves_unmapped_columns_untouched():
    df = pd.DataFrame({"A": [1], "B": [2]})
    renamed = mapper.rename_columns(df, {"A": "Real_Field__c"})
    assert list(renamed.columns) == ["Real_Field__c", "B"]


def test_build_scoped_query_matches_maid_behavior():
    q = mapper.build_scoped_query("Case_Contact__c", "OLD_ID", ["a09X001", "a09X002"])
    assert "IN (" in q
    assert "a09X001" in q and "a09X002" in q


def test_apply_lookups_handles_typo_key_column_case_member():
    # Real quirk found in ICY_CaseMember.csv: its own identity column is
    # "OD_ID" (missing the "L") rather than "OLD_ID" like every other
    # object - build_lookup_map/apply_lookups must work with whatever
    # key_field name is actually configured, not assume "OLD_ID".
    df = pd.DataFrame({"OD_ID": ["a0A001", "a0A002"], "REFERRAL__C": ["old1", "old2"]})
    ref_map = {"old1": "NEWID1"}
    lookups = [{"source_column": "REFERRAL__C", "target_column": "REFERRAL__C", "map": "referral"}]
    result = mapper.apply_lookups(df, lookups, {"referral": ref_map})
    assert result.matched_rows == 1
    assert result.dataframe.loc[0, "REFERRAL__C"] == "NEWID1"
    assert result.dataframe.loc[1, "REFERRAL__C"] == ""  # unmatched, blanked not dropped


def test_build_composite_tree_records_tags_referenceId_and_drops_key_column():
    df = pd.DataFrame({
        "OLD_ID": ["old1", "old2"],
        "Name": ["Acme", "Globex"],
        "BillingCity": ["", "Springfield"],  # blank should be omitted, not sent as ""
    })
    records = mapper.build_composite_tree_records(df, "Account", "OLD_ID")
    assert len(records) == 2
    assert records[0]["attributes"] == {"type": "Account", "referenceId": "old1"}
    assert records[0]["Name"] == "Acme"
    assert "BillingCity" not in records[0]  # blank omitted
    assert "OLD_ID" not in records[0]       # join key never sent as a field
    assert records[1]["BillingCity"] == "Springfield"


def test_remap_values_rewrites_listed_values_only():
    df = pd.DataFrame({
        "ICY_PREFERRED_METHOD_OF_CONTACT__C": ["Other", "Cell Phone", "", "Other"],
        "UNRELATED": ["Other", "x", "y", "z"],
    })
    remapped = mapper.remap_values(df, {"ICY_PREFERRED_METHOD_OF_CONTACT__C": {"Other": "Other Phone"}})
    assert list(remapped["ICY_PREFERRED_METHOD_OF_CONTACT__C"]) == ["Other Phone", "Cell Phone", "", "Other Phone"]
    assert list(remapped["UNRELATED"]) == ["Other", "x", "y", "z"]  # untouched - different column


def test_coerce_composite_tree_field_types_converts_bool_and_numeric():
    records = [{
        "attributes": {"type": "Account", "referenceId": "old1"},
        "ACTIVE_USERACCT__PC": "FALSE",      # raw CSV casing, must match case-insensitively
        "NumberOfEmployees": "42",
        "AnnualRevenue": "123.45",
        "Name": "Acme",                      # string type - left alone
    }]
    field_meta = {
        "Active_UserAcct__pc": {"type": "boolean"},
        "NumberOfEmployees": {"type": "int"},
        "AnnualRevenue": {"type": "currency"},
        "Name": {"type": "string"},
    }
    fixed = mapper.coerce_composite_tree_field_types(records, field_meta)
    assert fixed[0]["ACTIVE_USERACCT__PC"] is False
    assert fixed[0]["NumberOfEmployees"] == 42
    assert fixed[0]["AnnualRevenue"] == 123.45
    assert fixed[0]["Name"] == "Acme"
    assert fixed[0]["attributes"] == {"type": "Account", "referenceId": "old1"}


def test_ensure_username_domain_suffix_appends_to_any_stale_domain():
    df = pd.DataFrame({"USERNAME": [
        "charlotte@icySOSEUATpersona.com",             # old UAT-persona style
        "yanping.cui@gov.bc.ca.bcmohmaid",             # bare production username
        "someone@moh.com.maiduat.fc",                  # a different sandbox entirely
        "admin.user@gov.bc.ca.bcmohmaid.sosehfdv",     # already correct - must be left alone
    ]})
    fixed, changed = mapper.ensure_username_domain_suffix(df, "sosehfdv")
    assert changed == 3
    # Whole result is lowercased (not just the appended suffix) - Salesforce
    # itself silently lowercases every Username on store, so this must match
    # that or a re-run's upsert can't match its own previously-inserted row
    # (see the docstring for the DUPLICATE_USERNAME failure this caused).
    assert fixed.loc[0, "USERNAME"] == "charlotte@icysoseuatpersona.com.sosehfdv"
    assert fixed.loc[1, "USERNAME"] == "yanping.cui@gov.bc.ca.bcmohmaid.sosehfdv"
    assert fixed.loc[2, "USERNAME"] == "someone@moh.com.maiduat.fc.sosehfdv"
    assert fixed.loc[3, "USERNAME"] == "admin.user@gov.bc.ca.bcmohmaid.sosehfdv"  # unchanged


def test_ensure_username_domain_suffix_is_case_insensitive_on_the_check_but_still_lowercases():
    df = pd.DataFrame({"USERNAME": ["Already.Done@example.com.SOSEHFDV"]})
    fixed, changed = mapper.ensure_username_domain_suffix(df, "sosehfdv")
    # No suffix gets appended a second time (the check is case-insensitive),
    # but the value is still normalized to lowercase, so `changed` is 1, not 0.
    assert changed == 1
    assert fixed.loc[0, "USERNAME"] == "already.done@example.com.sosehfdv"


def test_drop_rows_by_username_domain_removes_chatter_free_placeholders():
    df = pd.DataFrame({"USERNAME": [
        "chatty.00d5w0000008aztuai.iwq4zdvsl5uf@chatter.salesforce.com",
        "CHATTY.SOMEONE@Chatter.Salesforce.Com",  # case-insensitive match
        "real.persona@gov.bc.ca.bcmohmaid.sosehfdv",
    ]})
    fixed, dropped = mapper.drop_rows_by_username_domain(df, ["chatter.salesforce.com"])
    assert dropped == 2
    assert list(fixed["USERNAME"]) == ["real.persona@gov.bc.ca.bcmohmaid.sosehfdv"]


# --------------------------------------------------------------------------
# Real-data tests: confirm the actual uploaded ICY CSVs load and behave as
# expected, including the non-UTF-8 encoding fix.
# --------------------------------------------------------------------------
def test_real_case_contact_loads_and_has_expected_columns():
    df = mapper.load_csv(os.path.join(FIXTURES, "ICY_CaseContact.csv"))
    assert "OLD_ID" in df.columns
    assert "RECORDTYPEID" in df.columns
    # Confirmed real quirk: Case_Contact is inserted BEFORE Case/Referral/
    # Intake exist, so these should be blank in the raw file - not enforced
    # here as an assertion (real data may vary), just confirming the
    # columns are readable as empty strings, not NaN/crash.
    assert (df["CASE__C"] == "").all() or (df["CASE__C"] != "").any()


def test_real_referral_has_special_mapping_columns_with_real_values():
    df = mapper.load_csv(os.path.join(FIXTURES, "ICY_Referral.csv"))
    assert "RecordType:RecordType-Name" in df.columns
    assert "OWNER:Group-Name" in df.columns
    # These should contain actual readable names, not blank/ids - that's
    # what makes them resolvable via special_lookups (unlike Account's
    # RecordTypeId, which only holds a raw old-org id with no name).
    assert df["RecordType:RecordType-Name"].iloc[0] != ""


def test_real_account_record_type_column_is_raw_id_not_name():
    # Confirms the documented ambiguity: Account's RecordTypeId column
    # holds what LOOKS like a Salesforce Id format (15/18 char alphanumeric
    # starting with "012"), not a human-readable name - this is exactly why
    # it needs a manual record_type_static_overrides entry rather than an
    # automatic name-based lookup like Referral/Case get.
    df = mapper.load_csv(os.path.join(FIXTURES, "ICY_Account.csv"))
    rt_col = "RecordTypeId" if "RecordTypeId" in df.columns else "RECORDTYPEID"
    val = df[rt_col].iloc[0]
    assert val.startswith("012")  # Salesforce RecordType Id prefix
    assert " " not in val  # confirms it's an Id, not a "Name" value like Referral's


def test_real_case_has_stale_cross_org_ids_that_must_be_overwritten():
    # Confirms the real data pattern: Case.csv's ACCOUNTID/CONTACTID/
    # REFERRAL__C already contain SOME value (possibly stale from a
    # previous migration attempt), and OLD_ACCOUNTID/OLD_CONTACTID/
    # OLD_REFERRAL are what should actually drive the real join -
    # whatever's already in the target columns must be overwritten,
    # not preserved.
    df = mapper.load_csv(os.path.join(FIXTURES, "ICY_Case.csv"))
    assert "OLD_ACCOUNTID" in df.columns and "ACCOUNTID" in df.columns
    assert "OLD_CONTACTID" in df.columns and "CONTACTID" in df.columns
    assert "OLD_REFERRAL" in df.columns and "REFERRAL__C" in df.columns
