/************************************************************************************************
* Name      : GetCasePHNandVerify
* Author    : Ranadheer Reddy
* Purpose   : Verify duplicate PHNs and update Case warning/prevent-save fields.
************************************************************************************************/
public class GetCasePHNandVerify {

    private static final Set<String> MAID_DEATH_CASE_TYPES = new Set<String>{
        'MAiD Death Foreseeable',
        'MAiD Death Not Foreseeable',
        'Discontinuation of Planning: Death Prior',
        'MAiD Assessment of Eligibility'
    };

    private static final Set<String> MAID_PLANNING_CASE_TYPES = new Set<String>{
        'Discontinuation of Planning: Ineligible',
        'Discontinuation of Planning: Withdrawn Request'
    };

    // Prevent the active after-save Flow from restoring a warning cleared during a transfer.
    private static Set<Id> casesWithTransferredWarnings = new Set<Id>();

    // Matches the active Flow's caseRecord and oldPHN inputs.
    public class CasePHNRequest {
        @InvocableVariable(required=true)
        public Case caseRecord;

        @InvocableVariable
        public String oldPHN;

        public CasePHNRequest() {
        }
    }

    @InvocableMethod(label='update case record' description='verify case phn and update')
    public static void getCasePHNandUpdate(List<CasePHNRequest> requests) {
        if (requests == null || requests.isEmpty() || requests[0]?.caseRecord?.Id == null) {
            return;
        }

        try {
            // Querying the various field values of the current case
            Case currentCase = [SELECT Id, RecordTypeId, Type, Status, PHN__c,
                                Prevent_save_on_duplicate_PHN__c, Warning_Message_If_Any__c
                                FROM Case WHERE Id = :requests[0].caseRecord.Id LIMIT 1];

            //VAriables for different comparisions                            
            String oldPHN = requests[0].oldPHN;
            Boolean phnChanged = oldPHN != currentCase.PHN__c;
            String originalWarning = currentCase.Warning_Message_If_Any__c;
            Boolean originalPreventSave = currentCase.Prevent_save_on_duplicate_PHN__c;
            Map<Id, Case> casesToUpdate = new Map<Id, Case>();

            // For update : Blanks out the Warning message on the other case matching the old phn.
            // A maximum of two cases, one with type = Death and the other with type = Planning can exist per PHN.
            // No two case of same type can exist per PHN
            if (phnChanged && !String.isBlank(oldPHN) && currentCase.Id != null) {
                for (Case oldPHNCase : [ SELECT Id, Warning_Message_If_Any__c FROM Case WHERE RecordTypeId = :currentCase.RecordTypeId
                                        AND Id != :currentCase.Id AND PHN__c = :oldPHN AND Warning_Message_If_Any__c != null
                ]) {
                    oldPHNCase.Warning_Message_If_Any__c = null;
                    casesToUpdate.put(oldPHNCase.Id, oldPHNCase);
                }
            }
            // A warning on the changed Case is stale until the new PHN checks below find a duplicate.
            if (phnChanged) {
                currentCase.Warning_Message_If_Any__c = null;
            }
            //Variables to check current case type
            Boolean currentIsDeathCase = MAID_DEATH_CASE_TYPES.contains(currentCase.Type);
            Boolean currentIsPlanningCase = MAID_PLANNING_CASE_TYPES.contains(currentCase.Type);

            // Logic only for Death and Planning type
            if (currentIsDeathCase || currentIsPlanningCase) {
                List<Case> existingCases = [ SELECT Id, Type, Status, Warning_Message_If_Any__c FROM Case
                                            WHERE RecordTypeId = :currentCase.RecordTypeId
                                            AND Id != :currentCase.Id
                                            AND PHN__c = :currentCase.PHN__c
                                            AND (Type IN :MAID_DEATH_CASE_TYPES OR Type IN :MAID_PLANNING_CASE_TYPES)
                                        ];

                currentCase.Prevent_save_on_duplicate_PHN__c = false;

                for (Case existingCase : existingCases) {
                    //Check for the other case's type tied tot he same PHN
                    Boolean existingIsDeathCase = MAID_DEATH_CASE_TYPES.contains(existingCase.Type);
                    Boolean existingIsPlanningCase = MAID_PLANNING_CASE_TYPES.contains(existingCase.Type);

                    Boolean shouldSetWarning = (currentIsDeathCase && existingIsPlanningCase) || (currentIsPlanningCase && existingIsDeathCase) ||
                                                (currentIsPlanningCase && existingIsPlanningCase && existingCase.Status == 'Closed');
                    if (shouldSetWarning &&
                        !casesWithTransferredWarnings.contains(currentCase.Id)) {
                        currentCase.Warning_Message_If_Any__c = Label.Duplicate_PHN_Warning;
                    }

                    if (currentIsDeathCase && existingIsDeathCase) {
                        currentCase.Prevent_save_on_duplicate_PHN__c = true;
                    }
                    if (currentIsPlanningCase && existingIsPlanningCase &&
                        existingCase.Status != 'Closed') {
                        currentCase.Prevent_save_on_duplicate_PHN__c = true;
                    }

                    //On phn update, if existing case matching current phn has a warning, blank it out and track it for this transaction.
                    Boolean isOppositeTypeMatch = (currentIsDeathCase && existingIsPlanningCase) || (currentIsPlanningCase && existingIsDeathCase);
                    if (phnChanged && isOppositeTypeMatch && !String.isBlank(existingCase.Warning_Message_If_Any__c)) {
                        existingCase.Warning_Message_If_Any__c = null;
                        casesWithTransferredWarnings.add(existingCase.Id);
                        casesToUpdate.put(existingCase.Id, existingCase);
                    }
                }
            }

            // Avoid no-op DML, including recursive Flow updates.
            if (currentCase.Id != null &&
                (currentCase.Warning_Message_If_Any__c != originalWarning ||
                 currentCase.Prevent_save_on_duplicate_PHN__c != originalPreventSave)) {
                casesToUpdate.put(currentCase.Id, currentCase);
            }

            if (!casesToUpdate.isEmpty()) {
                update casesToUpdate.values();
            }
        } catch (Exception e) {
            throw e;
        }
    }
}