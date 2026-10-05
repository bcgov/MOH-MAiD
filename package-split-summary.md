# MOH-MAiD package split — status & next steps

_Branch `feature/package-split` (commit `c8d3d6d9`, cut from `dev` @ `b805cfbe`) — **pushed to `origin` on 2026-10-01**. Component mapping also in `MOH-MAiD-package-split-mapping.xlsx` (repo root)._

## Status as of 2026-10-01

- Branch is on GitHub; the bundle file is no longer needed.
- **Pending team review**: the mapping (especially the 17 `base` rows and the 5 `needs review` rows in the Excel) and, once components are agreed, the package-identity decision (keep `maid` as the existing `MAiD - Case Management App` package vs. three new packages).
- **Blocked until then**: step 5 dry-run (needs an org alias) and step 6 package creation (needs Dev Hub alias). Nothing else is waiting on Claude.
- Any mapping changes from the review → give Claude the `type` + `component` rows to flip; the restructure commit will be regenerated.

## What was done

| Step | Status | Notes |
|---|---|---|
| 1 Inventory + reference graph | done | 2,467 components / 2,701 files, graph built from Apex, LWC/Aura, flows, layouts, flexipages, permsets, reports, formulas, relationship names |
| 2 Mapping | done (defaults assumed) | `docs/package-split/package-split-mapping.{md,csv}` on the branch |
| 3 Restructure | done | every file is a `git mv` — nothing deleted, no Apex or metadata edited |
| 4 `sfdx-project.json` | done | `base` (default, package `Base`), `icy` (package `ICY`), `maid` (keeps package **`MAiD - Case Management App`**), `unpackaged`; icy/maid depend on `Base 1.0.0.LATEST` |
| 5 Dry-run validation | **needs your machine** | Salesforce CLI/npm packages are blocked in the cloud sandbox and org auth is local — commands below |
| 6 Package creation | not started | waiting on Dev Hub alias + package-identity decision |

Assumptions made because the approval questions were not answered: mapping accepted as proposed; the three mixed items stay `unpackaged` with no edits; `maid` keeps the existing package id `0Ho5W000000002HSAQ` so installed orgs don't hit component-ownership conflicts.

## What moved where

| Directory | Files | Contents |
|---|---|---|
| `base/` | 17 | `Account`, `Case`, `PersonAccount`, `User` object definitions; Case fields `PHN__c`, `Province_or_Territory_that_issued_PHN__c`, `Gender__c`, `Record_Type_Name__c`, `ICY_Case_Owner__c`, `Practitioner_Name__c`, `Type`, `ParentId`, `ClosedDate`, `IsEscalated`; `Account.Fax`, `Account.PersonMobilePhone`; `Account.Required_Account_First_Name` validation rule |
| `icy/` | 1,264 | ICY app, 19 objects (Referral, Intake, Case_Contact, Case_Member, ICY_Notes/Document, YTS_*, System_Access_Request, IDP `__mdt`s …), 68 Apex classes, 6 triggers, 34 LWC, 4 Aura, 10 VF pages, 25 flows, 32 queues, 6 permsets + 5 PSGs, 71 reports, 3 dashboards, 8 email templates, all 56 custom labels, ICY-side Case/Account/Contact/User fields, record types, layouts |
| `maid/` | 1,332 | Case_Management app, 9 objects (Form_1632…1645, Form_RXMAR, S1_HC_2023), 5 Apex classes, 32 flows, Case workflow (19 Health-Canada rules), 9 permsets + 3 PSGs, 14 reports, entitlement process + 3 milestones, duplicate/matching rules, MAiD-side Case/Account/Contact fields, record types, layouts |
| `unpackaged/` | 88 | see below |
| `dev-app-post/`, `manifest/`, `config/`, `scripts/` | untouched | `dev-app-post` is still outside `packageDirectories` |

## Left in `unpackaged` and why

- 51 public groups, 8 roles — not packageable; ICY queues and sharing rules point at them.
- 13 sharing-rule files — owner-based rules reference the roles/groups above.
- 2 profiles (`MoH Standard User`, `ICYTest Profile`), 8 standard value sets, 2 settings files, `AppSwitcher` app menu — org-level.
- `ICYTest` site — depends on the guest profile.
- `PermissionSet:Salesforce_Backup_Administrator` — grants 687 MAiD + 479 ICY fields; putting it in either package creates a cycle. Option: split into two permsets.
- `FlexiPage:Practitioner_Page` — 2021 MAiD Account page that also lists `ICY_Close_Case` and the `ICY_Case_Owner__c` column. Option: remove those two references and move to `maid`.

## Validate on your machine (step 5)

```powershell
cd "C:\Users\srujan.neelapu\Documents\BC-Health\MOH-MAiD"
git fetch origin
git checkout feature/package-split
cd "MAiD - Case Management App"

# whole project, then per directory (replace <org> with your sandbox/scratch alias)
sf project deploy start --dry-run --target-org <org> --source-dir base --source-dir icy --source-dir maid --source-dir unpackaged
sf project deploy start --dry-run --target-org <org> --source-dir base
sf project deploy start --dry-run --target-org <org> --source-dir icy
sf project deploy start --dry-run --target-org <org> --source-dir maid
sf project deploy start --dry-run --target-org <org> --source-dir unpackaged
```

Deploying `icy` or `maid` alone assumes `base` (and the roles/groups in `unpackaged`) already exist in the org. Paste any "missing reference" errors back to me and I'll adjust the mapping.

## Install order (sandbox / prod)

1. `unpackaged` roles, groups, standard value sets, settings (and enable Person Accounts if the org doesn't have them)
2. `Base`
3. `ICY` and/or `MAiD - Case Management App` (ICY queues need the ICY roles/groups from step 1)
4. `unpackaged` profiles, sharing rules, `Practitioner_Page`, `Salesforce_Backup_Administrator`, `ICYTest` site
5. `dev-app-post` (as today)

## Things noticed on the way

- `maid/main/default/objects/PersonAccount/recordTypes/Physician.recordType-meta.xml` has an unescaped `&` on line 346 (`Family & Palliative Medicine`). Pre-existing on `dev`; strict parsers reject it.
- `.forceignore` was rewritten (27 paths). The `customMetadata` and IDP `__mdt` ignores now point at `icy/`.
- Local `origin/dev` on your machine appears older than GitHub's (`7832bd98` vs `b805cfbe`) — hence the `git fetch origin dev` above.
- Step 6 commands, once you confirm the Dev Hub alias: `sf package create --name Base --path base --package-type Unlocked --target-dev-hub <hub>`, `sf package create --name ICY --path icy --package-type Unlocked --target-dev-hub <hub>`, then `sf package version create --package Base --installation-key-bypass --code-coverage --wait 20 --target-dev-hub <hub>` and the same for `ICY` and `MAiD - Case Management App`.
