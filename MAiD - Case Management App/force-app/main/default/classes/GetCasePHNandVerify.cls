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
                
            //Querying the existing cases which consists of same PHN of triggering record based on case type
            //This process is never expected to be more than 1response. So we can avoid with looping the cases. The flow is never expected to pass more than 1 cases
            //caseList[0] is being used because there will be only one record in this scenario
            
            List<String> maidDeathCaseType = new List<String>{'MAiD Death Foreseeable', 'MAiD Death Not Foreseeable', 'Discontinuation of Planning: Death Prior', 'MAiD Assessment of Eligibility'};
            List<String> maidPlanningCaseType = new List<String>{'Discontinuation of Planning: Ineligible', 'Discontinuation of Planning: Withdrawn Request'};
            
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
                    update caseList[0];
                }
                
            }
    
            if(maidPlanningCaseType.contains(caseList[0].Type)){
                existingCases  = [Select
                                    Id, PHN__c, Type 
                                    From Case 
                                    Where RecordTypeId = :caseList[0].RecordTypeId AND Id != :caseList[0].Id AND PHN__C =: caseList[0].PHN__c ];
                caseList[0].Prevent_save_on_duplicate_PHN__c = false;
                if(existingCases!= NULL && !existingCases.isEmpty()){
                    for(Case cs : existingCases){
                        if(maidDeathCaseType.contains(cs.Type)){
                            caseList[0].Warning_Message_If_Any__c = 'There is an existing case in the database with the same PHN';
                        }else if(maidPlanningCaseType.contains(cs.Type)){
                            caseList[0].Warning_Message_If_Any__c = 'There is an existing case in the database with the same PHN';
                            if(cs.Type == caseList[0].Type){
                                caseList[0].Prevent_save_on_duplicate_PHN__c = true;
                            }
                        }
                    }
                    update caseList[0];
                }
                
            }
            
        } catch(Exception e){
            throw e;
        }
    }
  
    
}