public class DuplicatePHNHandler {
    public void beforeInsertUpdate(List<Case> caseList){
        for(Case c: caseList){
            try{
                List<Case> similarPHNs = [Select PHN__c, ParentId from Case where Id !=: c.Id and Type =: c.Type and Status != 'Closed' and PHN__c =: c.PHN__c];
        		
        		if(c.ParentId == null && similarPHNs.size() > 0 )
        		{
            		c.Prevent_save_on_duplicate_PHN__c = true;
        		}
        		else{
            		c.Prevent_save_on_duplicate_PHN__c = false;
        		}
        	}
        	catch(NullPointerException ae){
 				Trigger.new[0].addError(Label.Null_Pointer_Error_Message);
            }
        } 
    } 
}