global class CaseStatusDurationReportBatch implements Database.Batchable<SObject> {
	global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            'SELECT Id, Case_Created_Date__c, Case_Closed_Date__c, Status, CreatedDate, LastModifiedDate ' +
            'FROM Case ' +
            'WHERE RecordType.DeveloperName IN (\'ICY_Standard_Case\', \'ICY_Close_Case\') ' +
            'AND CreatedDate <= 2026-01-22T00:00:00Z'
        );

    }
    global void execute(Database.BatchableContext bc, List<Case> scope) {
        List<Case> caseToUpdate = new List<Case>();
        for(Case caseRecord : scope){
            Boolean isCaseUpdate = false;
            if(caseRecord.Case_Created_Date__c==null){
                caseRecord.Case_Created_Date__c = caseRecord.CreatedDate.date();
                isCaseUpdate = true;
            }
            if(caseRecord.Case_Closed_Date__c==null && caseRecord.Status=='Closed'){
              	caseRecord.Case_Closed_Date__c = caseRecord.LastModifiedDate.date();
                isCaseUpdate = true;
            }
            
            if(isCaseUpdate){
            	caseToUpdate.add(caseRecord);
        	}
        }
        if(!caseToUpdate.isEmpty()){
            update caseToUpdate;
        }
        
    }
    global void finish(Database.BatchableContext bc) {
        System.debug('IntakeStatusDurationReportBatch completed.');
    }
}