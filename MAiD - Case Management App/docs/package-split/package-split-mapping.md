# MOH-MAiD package split — proposed mapping (for approval)

Source analysed: `dev` branch of bcgov/MOH-MAiD (matches your local checkout), folder `MAiD - Case Management App/force-app`. 2467 components across 2699 files. Full per-component mapping is in `package-split-mapping.csv`.

## 1. Totals

| Package | Components |
|---|---|
| base | 17 |
| icy | 1036 |
| maid | 1326 |
| unpackaged | 88 |
| **total** | 2467 |

## 2. Mapping by metadata type

| Type | base | icy | maid | unpackaged |
|---|---|---|---|---|
| ApexClass |  | 68 | 5 |  |
| ApexPage |  | 10 |  |  |
| ApexTrigger |  | 6 |  |  |
| AppMenu |  |  |  | 1 |
| AuraDefinitionBundle |  | 4 |  |  |
| BusinessProcess |  | 1 | 2 |  |
| CompactLayout |  | 6 | 5 |  |
| ContentAsset |  |  | 1 |  |
| CustomApplication |  | 1 | 1 |  |
| CustomField | 12 | 584 | 1116 |  |
| CustomLabels |  | 1 |  |  |
| CustomMetadata |  | 1 |  |  |
| CustomNotificationType |  |  | 1 |  |
| CustomObject | 4 | 19 | 9 |  |
| CustomPermission |  | 1 |  |  |
| CustomSite |  |  |  | 1 |
| CustomTab |  | 4 |  |  |
| Dashboard |  | 3 |  |  |
| DashboardFolder |  | 2 |  |  |
| DuplicateRule |  |  | 1 |  |
| EmailFolder |  | 1 |  |  |
| EmailTemplate |  | 8 |  |  |
| EntitlementProcess |  |  | 1 |  |
| FlexiPage |  | 6 | 11 | 1 |
| Flow |  | 25 | 32 |  |
| FlowDefinition |  | 1 |  |  |
| GlobalValueSet |  | 5 | 1 |  |
| Group |  |  |  | 51 |
| Layout |  | 17 | 16 |  |
| LightningComponentBundle |  | 34 |  |  |
| ListView |  | 23 | 9 |  |
| MatchingRules |  |  | 1 |  |
| MilestoneType |  |  | 3 |  |
| PermissionSet |  | 6 | 9 | 1 |
| PermissionSetGroup |  | 5 | 3 |  |
| Profile |  |  |  | 2 |
| Queue |  | 32 |  |  |
| QuickAction |  | 24 |  |  |
| RecordType |  | 13 | 6 |  |
| Report |  | 71 | 14 |  |
| ReportFolder |  | 6 | 1 |  |
| ReportType |  | 10 | 1 |  |
| Role |  |  |  | 8 |
| Settings |  |  |  | 2 |
| SharingReason |  | 3 |  |  |
| SharingRules |  |  |  | 13 |
| StandardValueSet |  |  |  | 8 |
| StaticResource |  | 4 |  |  |
| ValidationRule | 1 | 27 | 76 |  |
| WebLink |  | 1 |  |  |
| Workflow |  | 3 | 1 |  |

## 3. `base` package — everything in it

Base ended up small: the two apps share the standard objects and only a handful of Case/Account fields. Everything else is one-sided.

| Type | Component | Why base |
|---|---|---|
| CustomField | `Account.Fax` | reachable from both ICY and MAiD |
| CustomField | `Account.PersonMobilePhone` | unreferenced & neutral → base (review) |
| CustomField | `Case.ClosedDate` | reachable from both ICY and MAiD |
| CustomField | `Case.Gender__c` | reachable from both ICY and MAiD |
| CustomField | `Case.ICY_Case_Owner__c` | reachable from both ICY and MAiD |
| CustomField | `Case.IsEscalated` | reachable from both ICY and MAiD |
| CustomField | `Case.PHN__c` | referenced (transitively) by both projects |
| CustomField | `Case.ParentId` | reachable from both ICY and MAiD |
| CustomField | `Case.Practitioner_Name__c` | reachable from both ICY and MAiD |
| CustomField | `Case.Province_or_Territory_that_issued_PHN__c` | referenced (transitively) by both projects |
| CustomField | `Case.Record_Type_Name__c` | reachable from both ICY and MAiD |
| CustomField | `Case.Type` | reachable from both ICY and MAiD |
| CustomObject | `Account` | standard object shared by both |
| CustomObject | `Case` | standard object shared by both |
| CustomObject | `PersonAccount` | standard object shared by both |
| CustomObject | `User` | standard object shared by both |
| ValidationRule | `Account.Required_Account_First_Name` | unreferenced & neutral → base (review) |

## 4. `unpackaged` — and why

| Type | # | Components | Reason |
|---|---|---|---|
| AppMenu | 1 | `AppSwitcher` | Org-level app switcher order |
| CustomSite | 1 | `ICYTest` | ICYTest site depends on guest-user profile `ICYTest Profile` |
| FlexiPage | 1 | `Practitioner_Page` | `Practitioner_Page` (MAiD Account page, 2021) also shows the ICY_Close_Case action, ICY_Close_Case record type and ICY_Case_Owner__c column → mixed |
| Group | 51 | `All_ICY_Admins` … `ICY_Restiricted_Data` | Public groups are not packageable; ICY queues and sharing rules reference them |
| PermissionSet | 1 | `Salesforce_Backup_Administrator` | `Salesforce_Backup_Administrator` grants fields from BOTH projects (687 MAiD + 479 ICY) — it cannot live in either package without creating a base→project cycle |
| Profile | 2 | `ICYTest Profile`, `MoH Standard User` | Profiles are not packageable in unlocked packages |
| Role | 8 | `ICY` … `MAiD_Manager` | Roles are not packageable |
| Settings | 2 | `Activities`, `PlatformEncryption` | Org settings (Activities, PlatformEncryption) |
| SharingRules | 13 | `Account` … `User` | Owner-based rules reference roles/groups; keep with org config |
| StandardValueSet | 8 | `AccountType` … `TaskSubject` | Not packageable (CaseStatus etc. carry both projects' values) |

## 5. Circular / mixed references and how to resolve them

After classification there are **no base→project references and no ICY↔MAiD references** in the packaged code. The only mixed items were pushed to `unpackaged`; each has a cleaner option:

| Item | Problem | Options |
|---|---|---|
| `FlexiPage:Practitioner_Page` | MAiD Account record page that lists ICY quick action + ICY column | (a) keep `unpackaged` (no edit) — **default**; (b) remove the 2 ICY references and move to `maid` |
| `PermissionSet:Salesforce_Backup_Administrator` | Grants both projects' fields | (a) keep `unpackaged` — **default**; (b) split into `Backup_Admin_MAiD` + `Backup_Admin_ICY` permsets |
| `CustomField:Case.ICY_Case_Owner__c` | ICY-named field, but `MAiD_Analyst` permset grants it, so it is 'used by both' | (a) `base` by the rule — **default**; (b) drop the grant from `MAiD_Analyst` and move to `icy` |
| `CustomLabels` | Single labels file; all 56 labels are used only by ICY | Whole file goes to `icy` (no split needed). MAiD has no labels today |
| `Workflow:Case` | One file per object; all 19 rules/alerts are MAiD (Health Canada / forms) | Goes to `maid` intact |

## 6. Standard-object fields (the only place both projects overlap)

| Object | base | icy | maid |
|---|---|---|---|
| Account | 2 | 12 | 7 |
| Contact | 0 | 26 | 5 |
| Case | 10 | 142 | 169 |
| User | 0 | 3 | 0 |
| Activity | 0 | 0 | 1 |

Object definitions (`Account`, `Case`, `PersonAccount`, `User` `.object-meta.xml`) go to `base`; each project's fields, record types, validation rules, list views, compact layouts, business processes and page layouts on those objects go with the project. Unlocked packages support extending standard objects this way.

## 7. Project packages at a glance

### ICY (1036 components)

- **Objects** (19): `Case_Contact__c`, `Case_Member__c`, `Contribution__c`, `ICY_Document__c`, `ICY_Notes__c`, `ICY_Outage_Message_Settings__c`, `ICY_SSO_Settings__c`, `IDP_User_Registration_Permission_Set__mdt`, `IDP_User_Registration_User_Mapping__mdt`, `Intake__c`, `Login_Page_Messages__c`, `Mapping_object__c`, `Postal_Code__c`, `Referral__c`, `System_Access_Request__c`, `YTS_Goal_Steps__c`, `YTS_Haves_And_Needs__c`, `YTS_Transition_Plan__c`, `YTS_Trigger_Handler__mdt`
- **App** (1): `ICY`
- **Apex classes** (68): `BatchOnCaseTeamSize`, `BatchOnCaseTeamSize_Test`, `CaseStatusDurationReportBatch`, `CaseStatusDurationReportBatchTest`, `ClearDraftReferralScheduler`, `ClearDraftReferralSchedulerTest`, `ICYNotesTriggerHandler`, `ICYNotesTriggerHandlerTest`, `ICYRegistrationLoginController`, `ICYRegistrationLoginControllerTest`, `ICYSelfRegistrationController`, `ICYSelfRegistrationControllerTest`, `ICY_AccessCaseController`, `ICY_AccessCaseControllerTest`, `ICY_AlertBannerCtrl`, `ICY_BatchToSendInactiveCaseNotes`, `ICY_BatchToSendInactiveCaseNotesTest`, `ICY_CaseMemberTriggerHandler`, `ICY_CaseMemberTriggerHandlerTest`, `ICY_CaseMember_Controller`, `ICY_CaseMember_Controller_Test`, `ICY_CaseNotesHandler`, `ICY_CaseNotesHandlerTest`, `ICY_CaseTriggerHandler`, `ICY_CaseTriggerHandlerTest`, `ICY_CompleteIntakeCtrl`, `ICY_CustomSettingsController`, `ICY_CustomSettingsControllerTest`, `ICY_IntakeFlowHandler`, `ICY_IntakeFlowHandlerTest`, `ICY_IntakeNotesHandler`, `ICY_IntakeNotesHandlerTest`, `ICY_IntegratedCarePlanCtrl`, `ICY_IntegratedCarePlanCtrlTest`, `ICY_Notes_Documents_Controller`, `ICY_Notes_Documents_ControllerTest`, `ICY_ReferralFeatureUtilityTest`, `ICY_ReferralFlowHandler`, `ICY_Referral_Controller`, `ICY_Referral_ControllerTest`, `ICY_ReopenCaseCtrl`, `ICY_SystemAccessRequestEmailTrigger_Test`, `ICY_UserRegistrationHandler`, `ICY_UserRegistrationHandlerTest`, `ICY_Utility`, `ICY_UtilityTest`, `IntakeStatusDurationReportBatch`, `IntakeStatusDurationReportBatchTest`, `NewsAnnouncements …
- **Triggers** (6): `Case_Member`, `ICYNotesTrigger`, `ICY_SystemAccessRequestEmailTrigger`, `IntakeTrigger`, `ReferralTrigger`, `YTS_Case_Trigger`
- **LWC** (34): `iCY_NotesComponent`, `icyAcceptCompleteIntake`, `icyAlertBanner`, `icyAlertBannerOutage`, `icyAlertBannerPrivacyAgreement`, `icyCaseTeamMembers`, `icyCloseReferral`, `icyCompleteIntakeLWC`, `icyContactsComponent`, `icyCreateEditCaseTeamMember`, `icyCreateEditDocument`, `icyCreateEditNotes`, `icyCreateInTakeRecord`, `icyCustomLookupComponent`, `icyDisableBannerAlert`, `icyDocumentsComponent`, `icyEnableBanner`, `icyIntegratedCarePlan`, `icyMyCases`, `icyNewReferral`, `icyNotes`, `icyPlansAddHavesAndNeeds`, `icyPlansAddStep`, `icyReReferral`, `icyReferralRecordInfo`, `icyReopenCase`, `icyReopenIntake`, `icyReopenReferral`, `ytsAccountInfo`, `ytsAddContact`, `ytsCaseAccountTab`, `ytsCasePrintPlan`, `ytsConfirmationModal`, `ytsCreateEditReferralContact`
- **Aura** (4): `ICY_New_Referral_Wrapper`, `ICY_Notes_Documents_Container`, `YTS_Referral_Name`, `YTS_STADD_CreateReferral_Wrapper`
- **VF pages** (10): `CaseNewOverride`, `CommunitiesSelfRegConfirm`, `Help_Case_Document_VF`, `ICYSelfRegistration`, `IndividualNameHeader_Account`, `IndividualNameHeader_Referral`, `IntegrateLogin`, `NewsAnnouncements_page`, `YTS_Custom_Plan_Print`, `YTS_Print_Transition_Plans`
- **Flows** (25): `Case_Close_Flow`, `Case_Report_ICY`, `ICY_Intake_Assign_To`, `ICY_Intake_Assign_To_Handler`, `ICY_Intake_Assignment_Notification`, `ICY_Intake_Reopen_Flow`, `ICY_Referral_Assign_To`, `ICY_Referral_Assign_To_Handler`, `ICY_Referral_Owner_Assignment_Flow`, `ICY_Referral_Owner_Email_Flow`, `ICY_Referral_PHN_Formatting`, `ICY_Referral_Update_PersonBirthdate`, `ICY_SendCaseMemberEmailNotification`, `ICY_Sync_Referral_Preferred_Name_From_Account`, `ICY_Update_ICY_Last_Case_Note_Date`, `Intake_Close_Flow`, `Intake_Report_Flow`, `Referral_Report_Flow`, `Sync_Case_ConsenttoEvaluation_to_RelatedIntakes`, `Sync_Intake_ConsenttoEvaluation_to_RelatedCase`, `Update_Individual_Community_Based_on_Physical_Address_Code`, `Update_Intake_Geographical_Region`, `Update_Intake_Owner_Based_on_Eligibility_Coordinator`, `Update_Owner_Based_on_Eligibility_Coordinator`, `Update_Privacy_Acknowledgement`
- **Permission sets** (6): `ICY_Administrator_Permissions`, `ICY_Clinical_Team_Member_Permissions`, `ICY_Integrate_Permissions`, `ICY_Non_Clinical_Team_Member_Permissions`, `ICY_Program_Leader_Permissions`, `ICY_Support_Permissions`
- **PSGs** (5): `ICY_Administrator_Permission_Set_Group`, `ICY_Business_Administrator_PSG`, `ICY_Clinical_Team_Member_Permission_Set_Group`, `ICY_Non_Clinical_Team_Member_Permission_Set_Group`, `ICY_Program_Leader_Permission_Set_Group`
- **Record types** (13): `Account.ICY_Person_Account`, `Case.ICY_Close_Case`, `Case.ICY_Standard_Case`, `Case_Contact__c.ICY_Case_Contact`, `Intake__c.ICY_Intake`, `Intake__c.ICY_Intake_Read_Only`, `PersonAccount.ICY_Person_Account`, `Referral__c.ICY_General`, `Referral__c.ICY_General_Read_Only`, `Referral__c.ICY_Medical`, `Referral__c.ICY_Medical_Read_Only`, `Referral__c.Read_Only`, `System_Access_Request__c.ICY`
- **Flexipages** (6): `Case_Contact_Record_Page`, `ICY_Cases_Record_Page`, `ICY_Home_Page`, `ICY_Intake_Record_Page`, `ICY_Person_Account`, `ICY_Referral_Record_Page`
- **Layouts** (17): `Case-ICY_Close_layout`, `Case-ICY_Standard`, `Contribution__c-Contribution Layout`, `Intake__c-ICY Intake Layout`, `Login_Page_Messages__c-Login Page Messages Layout`, `Mapping_object__c-Mapping object Layout`, `PersonAccount-ICY Person Account Layout`, `PersonAccount-Person Account Layout %28admin%29`, `Postal_Code__c-Postal Code Layout`, `Referral__c-ICY General Close Layout`, `Referral__c-ICY General Layout`, `Referral__c-ICY Medical Close Layout`, `Referral__c-ICY Medical Layout`, `Referral__c-Read-Only`, `System_Access_Request__c-System Access Request Layout`, `User-User Layout`, `YTS_Trigger_Handler__mdt-YTS Trigger Handler Layout`
- **Queues** (32): `ICY_Central_Coast`, `ICY_Coast_Mountains_Team_Hazelton`, `ICY_Coast_Mountains_Team_Terrace`, `ICY_Comox_Valley_Team_1`, `ICY_Comox_Valley_Team_2`, `ICY_Cowichan_Valley`, `ICY_Delta`, `ICY_Fraser_Cascades`, `ICY_Gold_Trail`, `ICY_Kootenay_Columbia`, `ICY_Maple_Ridge_Pitt_Meadows_Team_1`, `ICY_Maple_Ridge_Pitt_Meadows_Team_2`, `ICY_Maple_Ridge_Pitt_Meadows_Team_3`, `ICY_Mission_Team_1`, `ICY_Mission_Team_2`, `ICY_Mission_Team_3`, `ICY_Nanaimo_Ladysmith_Team_1`, `ICY_Nanaimo_Ladysmith_Team_2`, `ICY_Nanaimo_Ladysmith_Team_3`, `ICY_Nanaimo_Ladysmith_Team_4`, `ICY_Nicola_Similkameen`, `ICY_North_Okanagan_Shuswap`, `ICY_Okanagan_Similkameen`, `ICY_Pacific_Rim`, `ICY_Peace_River_South`, `ICY_Qualicum`, `ICY_Richmond_Team_1`, `ICY_Richmond_Team_2`, `ICY_Richmond_Team_3`, `ICY_Richmond_Team_4`, `ICY_Surrey`, `ICY_qathet_Powell_River`
- **Report types** (10): `Case_Transition_Goals`, `Cases_with_Case_Contacts`, `ICY_Case_with_CaseMembers`, `ICY_Cases_with_or_without_Case_Notes`, `ICY_Open_Cases_With_ConsentToEvaluation`, `MMHA_Case_Transition_HaveNeeds_Goals`, `MMHA_Reporting_Report_Type`, `Referral_With_Intake_and_Cases`, `Referral_with_Case`, `Shared_Indicators_Intakes`
- **Global value sets** (5): `Domains`, `Haves_And_Needs_List`, `Legal_Status_List`, `Preferred_Method_Of_Contact`, `Secondary_Eligibility_Type`
- **Static resources** (4): `Help_Case_document`, `SiteSamples`, `YTS_Styles`, `icy_branding`
- **Workflows** (3): `Case_Contact__c`, `Intake__c`, `Referral__c`
- **Email templates** (8): `ICY_Email_Templates/Critical_Notification_Alert`, `ICY_Email_Templates/ICY_Intake_Assignment_Notification_Latest`, `ICY_Email_Templates/ICY_Portal_Registration_Notification`, `ICY_Email_Templates/ICY_Referral_Updated_Template`, `ICY_Email_Templates/Intake_Ownership_Transfer`, `ICY_Email_Templates/Referral_Owner_Email_Template`, `ICY_Email_Templates/Referral_Ownership_Transfer`, `ICY_Email_Templates/Referral_Status_Closed_Template`

### MAiD (1326 components)

- **Objects** (9): `Form_1632__c`, `Form_1633__c`, `Form_1634__c`, `Form_1635__c`, `Form_1641__c`, `Form_1642__c`, `Form_1645__c`, `Form_RXMAR__c`, `S1_HC_2023__c`
- **App** (1): `Case_Management`
- **Apex classes** (5): `DeleteAssessmentofEligibilityBatchTest`, `DeleteAssessmentofEligibilityCasesBatch`, `GetCasePHNandVerify`, `GetCasePHNandVerifyTest`, `TestDataFactory`
- **Flows** (32): `Case_After_Update_Reportable_to_Health_Canada_BCCS_Manager_Review_Required_Rule`, `Federal_Safeguards`, `Form_1634_Report_Template`, `Legislation_Safeguards`, `MAiD_Case_Stage_Changes_AFTER`, `MAiD_Case_Stages_BEFORE`, `MAiD_Flows_Q25`, `MAiD_Flows_Q40_41_42`, `MAiD_Flows_Q55`, `MAiD_Flows_Q70`, `MAiD_Flows_WOR_Q05`, `MAiD_Prevent_Duplicate_Phn`, `Mandatory_Data`, `Provincial_Safeguards`, `Provincial_and_RX_Flow_for_1633`, `Status6_Update`, `Status7_Update`, `Status_4_update`, `Status_5_update_flow`, `Status_update_prevention`, `Update_1632`, `Update_1633`, `Update_1634`, `Update_1641`, `Update_1642`, `Update_1645`, `Update_Related_Case_Record`, `Update_Rx_MAR`, `check_for_existing_open_case_with_same_PHN`, `display_warning_for_duplicate_phn`, `notification_sender_flow`, `update_provincial_safeguard_field`
- **Permission sets** (9): `MAiD_Analyst`, `MAiD_Analyst_Reports_Dashboards`, `MAiD_Manage_Encryption_Keys`, `MAiD_Manager`, `MAiD_Reports_Analyst`, `MAiD_Reports_Dashboards`, `MAiD_System_Administrator`, `MoH_Manage_Encryption_Keys`, `Two_factor_Authentication`
- **PSGs** (3): `MAiD_Admin_Group`, `MAiD_Analyst_Group`, `MAiD_Manager_1_Group`
- **Record types** (6): `Case.Error_Log`, `Case.MAiD_Case`, `PersonAccount.Nurse_Practitioner`, `PersonAccount.Other_Health_Care_Professionals`, `PersonAccount.Pharmacist`, `PersonAccount.Physician`
- **Flexipages** (11): `Case_Management_Home_Page`, `Case_Management_UtilityBar`, `Case_Record_Page`, `Form_1632_Page`, `Form_1633_Page`, `Form_1634_Page`, `Form_1635_Page`, `Form_1641_Page`, `Form_1642_Page`, `Form_1645_Page`, `Form_Rx_MAR_Page`
- **Layouts** (16): `Case-MAiD Case Layout`, `Case-MAiD Error Log`, `Form_1632__c-Form 1632 Layout`, `Form_1633__c-Form 1633 Layout`, `Form_1634__c-Form 1634 Layout`, `Form_1635__c-Form 1635 Layout`, `Form_1641__c-Form 1641 Layout`, `Form_1642__c-Form 1642 Layout`, `Form_1645__c-Form 1645 Layout`, `Form_RXMAR__c-Form Rx%2FMAR Layout`, `PersonAccount-Nurse Practitioner`, `PersonAccount-Other Health Care Professionals`, `PersonAccount-Pharmacist`, `PersonAccount-Physician`, `S1_HC_2023__c-S1 HC 2023 Layout`, `Task-Task Layout`
- **Report types** (1): `Form_1634_with_S1_HC_2023`
- **Global value sets** (1): `Missed_Error_Log_Issue`
- **Workflows** (1): `Case`

## 8. How confident is each row?

| Basis | Components |
|---|---|
| reference graph (strong) | 2063 |
| git history tiebreaker (medium) | 113 |
| by what it references (medium) | 110 |
| type rule | 86 |
| follows its object (strong) | 83 |
| weak / review | 5 |
| test follows tested class | 4 |
| manual override | 3 |

The git tiebreaker: ICY entered this repo in commit `e492d107` (2023-12-15, "ICY Integrate complete migration"). Unreferenced components first added before that date are MAiD; ones added by ICY/BCMOHAM-tagged commits are ICY. Rows with `review` in the reason column of the CSV are the ones I'd eyeball.

## 9. Things you should know before I move anything

- **Existing package conflict.** `sfdx-project.json` already defines the unlocked package `MAiD - Case Management App` (0Ho5W000000002HSAQ, versions up to 1.9.4-1 on `dev`, 2.4.1 on `main`). A component can belong to only one unlocked package per org. If that package is installed in your sandboxes/prod, a *new* `Base` package containing `Case`/`Account` fields will fail to install with 'component already in another package'. Options: (a) keep `MAiD - Case Management App` as the *MAiD* package and only create `Base` + `ICY` as new packages, then move base components out via a MAiD version that removes them; (b) brand-new set of three packages and uninstall the old one in lower envs first. This decides the `package` names in step 4.
- **Branch.** Your local checkout is `dev`; `main` differs by 9 files (mostly `sfdx-project.json` version aliases and one permset). I'll branch `feature/package-split` from `dev` unless you say `main`.
- **`dev-app-post/`** (UserRegistrationService, UserPermissionsTrigger, `User.Keycloak_Roles__c`, 121 IDP custom-metadata records) is a post-deploy folder that is *not* in `packageDirectories` today. It mixes ICY and MAiD permset mappings. I'll leave it untouched and not package it.
- **`.forceignore`** lists 17 `force-app/main/default/...` paths (lookup-filter fields, six reports, the IDP `__mdt` objects, `customMetadata`). Those paths must be rewritten to the new directories or the ignores silently stop working.
- **Install order for a sandbox**: (1) `unpackaged` roles, groups, standard value sets, settings; (2) `Base`; (3) `ICY` and/or `MAiD` (ICY queues need the ICY roles/groups from step 1); (4) `unpackaged` profiles, sharing rules, `Practitioner_Page`, `Salesforce_Backup_Administrator`, site. Both apps need Person Accounts enabled in the target org.
- `manifest/`, `config/`, `scripts/`, `package.json` stay where they are.
- The two `.eslintrc.json` files under `lwc/` and `aura/` will be copied into each package dir that has bundles (only `icy` today).

## 10. Proposed `sfdx-project.json`

```json
{
  "packageDirectories": [
    {
      "path": "base",
      "default": true,
      "package": "Base",
      "versionName": "ver 1.0",
      "versionNumber": "1.0.0.NEXT"
    },
    {
      "path": "icy",
      "package": "ICY",
      "versionName": "ver 1.0",
      "versionNumber": "1.0.0.NEXT",
      "dependencies": [
        {
          "package": "Base",
          "versionNumber": "1.0.0.LATEST"
        }
      ]
    },
    {
      "path": "maid",
      "package": "MAiD",
      "versionName": "ver 1.0",
      "versionNumber": "1.0.0.NEXT",
      "dependencies": [
        {
          "package": "Base",
          "versionNumber": "1.0.0.LATEST"
        }
      ]
    },
    {
      "path": "unpackaged"
    }
  ],
  "namespace": "",
  "sfdcLoginUrl": "https://login.salesforce.com",
  "sourceApiVersion": "65.0",
  "packageAliases": {
    "MAiD - Case Management App": "0Ho5W000000002HSAQ",
    "\u2026existing version aliases kept\u2026": "\u2026"
  }
}
```

## 11. What I need from you

- Approve the mapping (or tell me which rows to flip — the CSV `type`+`name` is enough).
- Decide the three mixed items in section 5 (defaults are the no-edit options).
- Package naming vs the existing `MAiD - Case Management App` package (section 9, first bullet).
- Target org alias for the `--dry-run` validation, and — only if you want packages created — the Dev Hub alias.