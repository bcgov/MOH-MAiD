/************************************************************************************************
* Name      : GetCasePHNandVerify                                                         
* Author    : Ranadheer Reddy                                                                                                                                                                 *
* Purpose   :"This Class is called from flow to verify if the duplicate PHN exists and stop the current record from saving if the case exists with same PHN"                                                                                     
************************************************************************************************/
public class GetCasePHNandVerify {

    /*    
    ** Method Name: getCasePHNandUpdate
    ** Created by: Ranadheer Reddy
    ** Created Date: 07-26-2023
    ** Parameters : caseList
    ** Return Type :void
    ** Description : this method is to verify if the duplicate PHN exists and stop the current record from saving if the case exists with same PHN
    */
    @InvocableMethod(label = 'update case record' description = 'verify case phn and update')
    public static void getCasePHNandUpdate(List<Case> caseList){

        try {
            List<Case> existingCases;
            Boolean preventUpdate = false;
                
            //Querying the existing cases which consists of same PHN of triggering record based on case type
            //This process is never expected to be more than 1response. So we can avoid with looping the cases. The flow is never expected to pass more than 1 cases
            //caseList[0] is being used because there will be only one record in this scenario
            
            List<String> maidDeathCaseType = new List<String>{'MAiD Death Foreseeable', 'MAiD Death Not Foreseeable', 'Discontinuation of Planning: Death Prior', 'MAiD Assessment of Eligibility'};
            List<String> maidPlanningCaseType = new List<String>{'Discontinuation of Planning: Ineligible', 'Discontinuation of Planning: Withdrawn Request'};
            String originalWarning = caseList[0].Warning_Message_If_Any__c;
            
            if(maidDeathCaseType.contains(caseList[0].Type)){
                existingCases  = [Select
                                    Id, PHN__c, Type
                                    From Case 
                                    Where RecordTypeId = :caseList[0].RecordTypeId AND Id != :caseList[0].Id AND PHN__C =: caseList[0].PHN__c ];
                caseList[0].Prevent_save_on_duplicate_PHN__c = false;
                if(existingCases!= NULL && !existingCases.isEmpty()){
                    for(Case cs : existingCases){
                        if(maidPlanningCaseType.contains(cs.Type)){
                            caseList[0].Warning_Message_If_Any__c = 'There is an existing case in the database with the same PHN';
                        }else if(maidDeathCaseType.contains(cs.Type)){
                            caseList[0].Prevent_save_on_duplicate_PHN__c = true;
                        }
                    }
                }
                if(existingCases == NULL || existingCases.isEmpty()){
                    caseList[0].Warning_Message_If_Any__c = null;
                }
                if(caseList[0].Warning_Message_If_Any__c != originalWarning || caseList[0].Prevent_save_on_duplicate_PHN__c){
                    update caseList[0];
                }
                
            }
    
            if(maidPlanningCaseType.contains(caseList[0].Type)){
                existingCases  = [Select
                                    Id, PHN__c, Type, Status
                                    From Case 
                                    Where RecordTypeId = :caseList[0].RecordTypeId AND Id != :caseList[0].Id AND PHN__C =: caseList[0].PHN__c ];
                caseList[0].Prevent_save_on_duplicate_PHN__c = false;
                if(existingCases!= NULL && !existingCases.isEmpty()){
                    for(Case cs : existingCases){
                        if(maidDeathCaseType.contains(cs.Type) || maidPlanningCaseType.contains(cs.Type)){
                            caseList[0].Warning_Message_If_Any__c = 'There is an existing case in the database with the same PHN';
                            if (maidPlanningCaseType.contains(cs.Type) && cs.Status != 'Closed'){
                                preventUpdate = true;
                            }
                        }
                    }
                    if (preventUpdate){
                        caseList[0].Prevent_save_on_duplicate_PHN__c = true;
                    }
                }
                if(existingCases == NULL || existingCases.isEmpty()){
                    caseList[0].Warning_Message_If_Any__c = null;
                }
                if(caseList[0].Warning_Message_If_Any__c != originalWarning || caseList[0].Prevent_save_on_duplicate_PHN__c){
                    update caseList[0];
                }
            }
            if(maidDeathCaseType.contains(caseList[0].Type) || maidPlanningCaseType.contains(caseList[0].Type)){
                clearStaleDuplicateWarnings();
            }
            
        } catch(Exception e){
            throw e;
        }
    }

    // Clear a warning only when no other MAiD Case remains with the same record type and PHN.
    private static void clearStaleDuplicateWarnings(){
        String duplicateWarning = 'There is an existing case in the database with the same PHN';
        List<Case> warnedCases = [
            SELECT Id, PHN__c, RecordTypeId
            FROM Case
            WHERE RecordType.DeveloperName = 'MAiD_Case'
                AND Warning_Message_If_Any__c = :duplicateWarning
        ];
        if(warnedCases.isEmpty()){
            return;
        }

        Set<String> phns = new Set<String>();
        Set<Id> recordTypeIds = new Set<Id>();
        for(Case warnedCase : warnedCases){
            if(warnedCase.PHN__c != null){
                phns.add(warnedCase.PHN__c);
                recordTypeIds.add(warnedCase.RecordTypeId);
            }
        }

        Map<String, Set<Id>> matchingCaseIdsByRecordTypeAndPhn = new Map<String, Set<Id>>();
        if(!phns.isEmpty()){
            for(Case matchingCase : [
                SELECT Id, PHN__c, RecordTypeId
                FROM Case
                WHERE RecordTypeId IN :recordTypeIds AND PHN__c IN :phns
            ]){
                String key = String.valueOf(matchingCase.RecordTypeId) + '|' + matchingCase.PHN__c;
                if(!matchingCaseIdsByRecordTypeAndPhn.containsKey(key)){
                    matchingCaseIdsByRecordTypeAndPhn.put(key, new Set<Id>());
                }
                matchingCaseIdsByRecordTypeAndPhn.get(key).add(matchingCase.Id);
            }
        }

        List<Case> casesToClear = new List<Case>();
        for(Case warnedCase : warnedCases){
            String key = String.valueOf(warnedCase.RecordTypeId) + '|' + warnedCase.PHN__c;
            Set<Id> matchingIds = matchingCaseIdsByRecordTypeAndPhn.get(key);
            if(matchingIds == null || (matchingIds.size() == 1 && matchingIds.contains(warnedCase.Id))){
                casesToClear.add(new Case(Id = warnedCase.Id, Warning_Message_If_Any__c = null));
            }
        }

        if(!casesToClear.isEmpty()){
            update casesToClear;
        }
    }   
}