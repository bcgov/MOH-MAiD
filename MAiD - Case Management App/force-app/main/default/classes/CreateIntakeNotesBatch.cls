global class CreateIntakeNotesBatch implements Database.Batchable<SObject>, Database.Stateful {
    global String query;

   
    global CreateIntakeNotesBatch() {
        // adjust Status__c value if your org uses a different label/API value
        query = 'SELECT Id, ICY_Rationale__c, Closed_Reason__c FROM Intake__c WHERE Status__c = \'Closed\'';
    }

     global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(query);
    }


    global void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<Intake__c> intakes = (List<Intake__c>) scope;
        List<ICY_Notes__c> toInsert = new List<ICY_Notes__c>();
      
        for (Intake__c i : intakes) {
          if (i.ICY_Rationale__c != null){
                
            ICY_Notes__c n = new ICY_Notes__c();
            n.Description__c = 'Rationale - ' + i.ICY_Rationale__c;
            n.Intake__c = i.Id;
            n.Name = 'Other';
            n.Notes_Type__c = 'Collaborative';
            n.Other__c ='Intake Closed Reason - ' +  i.Closed_Reason__c;
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