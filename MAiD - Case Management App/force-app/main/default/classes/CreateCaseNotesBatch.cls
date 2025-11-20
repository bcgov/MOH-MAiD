global class CreateCaseNotesBatch implements Database.Batchable<SObject>, Database.Stateful {
    global String query;

   
    global CreateCaseNotesBatch() {
       
        query = 'Select ICY_Rationale__c,Case_Closed_Reason__c from case where status = \'Closed\' and recordtypeId=\'012Mm000000pyLWIAY\'';
    }

     global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(query);
    }


    global void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<Case> cases = (List<Case>) scope;
        List<ICY_Notes__c> toInsert = new List<ICY_Notes__c>();
      
        for (Case c : cases) {
          if (c.ICY_Rationale__c != null){
                
            ICY_Notes__c n = new ICY_Notes__c();
            n.Description__c = c.ICY_Rationale__c;
            n.Case__c = c.Id;
            n.Name = 'Other';
            n.Notes_Type__c = 'Collaborative';
            n.Other__c = c.Case_Closed_Reason__c;
            n.Referral_Subject__c = 'Other';
            toInsert.add(n);
        }
       }

        if (!toInsert.isEmpty()) {
            try {
                insert toInsert;
            } catch (Exception e) {
                // log error - in production you might write to a custom log object or send email
                System.debug('Error inserting ICY_Notes__c batch: ' + e.getMessage());
            }
        }
    }

    global void finish(Database.BatchableContext bc) {
       System.debug('Batch job completed successfully.');
    }
}