global class UpdateCaseCreatedDateBatch implements Database.Batchable<SObject> {
    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            'SELECT Id, Case_Created_Date__c, Case_Closed_Date__c, Status, CreatedDate, LastModifiedDate ' +
            'FROM Case ' +
            'WHERE RecordType.DeveloperName IN (\'ICY_Standard_Case\', \'ICY_Close_Case\') ' +
            'AND CreatedDate < 2026-01-23T00:00:00Z'
        );

    }
    global void execute(Database.BatchableContext bc, List<Case> scope) {
        List<Case> caseToUpdate = new List<Case>();
        for(Case caseRecord : scope){
           System.debug('case id: ' + caseRecord.id + ' CreatedDate: ' +  caseRecord.CreatedDate.date()) ;  
                caseRecord.Case_Created_Date__c = caseRecord.CreatedDate.date();
                caseToUpdate.add(caseRecord);
        }
        if(!caseToUpdate.isEmpty()){
            update caseToUpdate;
        }
        
    }
    global void finish(Database.BatchableContext bc) {
        System.debug('UpdateCaseCreatedDateBatch completed.');
    }
}