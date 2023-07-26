public class GetCasePHNandVerify {
    
    @InvocableMethod(label = 'update case record' description = 'verify case phn and update')
    public static void getCasePHNandUpdate(List<Case> caseList){
        
        List<Case> existingCases;
                
        //Querying the existing cases which consists of same PHN of triggering record based on case type
        //This process is never expected to be more than 1response. So we can avoid with looping the cases. The flow is never expected to pass more than 1 cases
        //caseList[0] is being used because there will be only one record in this scenario
        
        if(caseList[0].Type == 'MAiD Assessment of Eligibility' && caseList[0].Status == 'Closed'){
            
            existingCases  = [Select Id, PHN__c From Case Where ((Type = 'MAiD Assessment of Eligibility' AND Status != 'Closed') OR ((Type = 'Discontinuation of Planning: Ineligible' OR Type  = 'Discontinuation of Planning: Withdrawn Request') AND Status = 'Closed')) AND RecordTypeId = :caseList[0].RecordTypeId AND Id != :caseList[0].Id AND PHN__C =: caseList[0].PHN__c ];
        
        }else if(caseList[0].Type == 'Discontinuation of Planning – Ineligible'){
            
            existingCases  = [Select Id, PHN__c From Case Where Type = 'Discontinuation of Planning: Ineligible' AND  RecordTypeId = :caseList[0].RecordTypeId AND Id != :caseList[0].Id AND PHN__C =: caseList[0].PHN__c ];
  
        }else{
            
            existingCases  = [Select Id, PHN__c From Case Where Type = :caseList[0].Type AND  RecordTypeId = :caseList[0].RecordTypeId AND Status != 'Closed' AND Id != :caseList[0].Id AND PHN__C =: caseList[0].PHN__c ];
        
        }     
        
       //Checking if there are any cases which are with the same PHN of triggering record 
        try{
             if(existingCases!= NULL && existingCases.size()>0){
            
               caseList[0].Prevent_save_on_duplicate_PHN__c = true;
               
               //updating the case if there are existing cases with the same PHN
               update caseList[0];
                
            }
        }catch(Exception e){
            System.debug('Exception Occured'+e.getTypeName()+'----'+e.getMessage());
        }
       
        
    }
 
}