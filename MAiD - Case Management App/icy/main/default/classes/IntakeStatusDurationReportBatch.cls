global class IntakeStatusDurationReportBatch implements Database.Batchable<SObject> {
	global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            'SELECT Id, Individual_Name__c, ' +
               'Case__r.CreatedDate, Not_Started_Date__c, Complete_Date__c, ' +
               'ICY_Intake_Close_Date__c, Status__c, LastModifiedDate, CreatedDate ' +
               'FROM Intake__c ' +
               'WHERE CreatedDate < 2026-01-23T00:00:00Z '
        );
    }
    global void execute(Database.BatchableContext bc, List<Intake__c> scope) {
        List<Intake__c> intakeToUpdate = new List<Intake__c>();
        for(Intake__c intake : scope){
            Boolean isIntakeUpdate = false;
            if(intake.Not_Started_Date__c==null){
                intake.Not_Started_Date__c = intake.CreatedDate.date();
                isIntakeUpdate = true;
            }
            if(intake.Complete_Date__c==null && intake.Case__r!=null){
              	intake.Complete_Date__c = intake.Case__r.CreatedDate.date();
                isIntakeUpdate = true;
            }
            if(intake.Status__c=='Closed' && intake.ICY_Intake_Close_Date__c==null){
                intake.ICY_Intake_Close_Date__c = intake.LastModifiedDate.date();
                isIntakeUpdate = true;
            }
            if(isIntakeUpdate){
            	intakeToUpdate.add(intake);
        	}
        }
        if(!intakeToUpdate.isEmpty()){
            update intakeToUpdate;
        }
        
    }
    global void finish(Database.BatchableContext bc) {
        System.debug('IntakeStatusDurationReportBatch completed.');
    }
}