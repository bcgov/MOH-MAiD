global class UpdateReferralOlderRecordsBatch implements Database.Batchable<SObject> {

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            'SELECT Id, CreatedDate, Ready_for_Intake_Date__c, Referral_Created_Date__c, Closed_Date__c, Status__c, LastModifiedDate, ' +
            ' Case_Created_Date__c, Intake__r.CreatedDate, Case__r.CreatedDate, Case__r.Status ,Case__r.Case_Closed_Date__c, Case__r.Case_Created_Date__c, Case__r.LastModifiedDate ' +
            'FROM Referral__c ' +
            'WHERE CreatedDate < 2026-01-22T00:00:00Z '
        );
    }

    global void execute(Database.BatchableContext bc, List<Referral__c> scope) {
		List<Referral__c> referralsToUpdate = new List<Referral__c>();
        Map<Id, Case> caseMap = new Map<Id, Case>();
		
        Map<Id, Date> referralVsIntakeDateMap = new Map<Id, Date>();
        Set<Id> referralIds = new Set<Id>();
        
        for (Referral__c ref : scope) {
            referralIds.add(ref.Id);
        }
        
        Map<Id, Date> childIntakeDateMap = new Map<Id, Date>();

        for (Intake__c intake : [
            SELECT Id, Referral__c, CreatedDate
            FROM Intake__c
            WHERE Referral__c IN :referralIds
        ]) {
            childIntakeDateMap.put(
                intake.Referral__c,
                intake.CreatedDate.date()
            );
        }
        
        
        for (Referral__c ref : scope) {
            if (ref.Intake__c != null && ref.Intake__r != null) {
                referralVsIntakeDateMap.put(
                    ref.Id,
                    ref.Intake__r.CreatedDate.date()
                );
            } else if (childIntakeDateMap.containsKey(ref.Id)) {
                referralVsIntakeDateMap.put(
                    ref.Id,
                    childIntakeDateMap.get(ref.Id)
                );
            }
        }
        
        for (Referral__c ref : scope) {
            Boolean isUpdated = false;
			if(ref.Closed_Date__c==null && ref.Status__c=='Closed'){
                ref.Closed_Date__c = ref.LastModifiedDate.date();
                isUpdated = true;
            }
            if (ref.Ready_for_Intake_Date__c == null && referralVsIntakeDateMap.containsKey(ref.Id)) {
                ref.Ready_for_Intake_Date__c = referralVsIntakeDateMap.get(ref.Id);
                isUpdated = true;
            }
            if (ref.Referral_Created_Date__c == null) {
                ref.Referral_Created_Date__c = ref.CreatedDate.date();
                isUpdated = true;
            }
            if (ref.Case_Created_Date__c == null && ref.Case__r != null) {
                ref.Case_Created_Date__c = ref.Case__r.CreatedDate.date();
                isUpdated = true;
            }
            if (ref.Case__r != null) {
                Case c;
    
                if (caseMap.containsKey(ref.Case__r.Id)) {
                    c = caseMap.get(ref.Case__r.Id);
                } else {
                    c = new Case(Id = ref.Case__r.Id);
                }
            
                if (ref.Case__r.Status == 'Closed' &&
                    ref.Case__r.Case_Closed_Date__c == null) {
            
                    c.Case_Closed_Date__c = ref.Case__r.LastModifiedDate.date();
                }
            
                if (ref.Case__r.Case_Created_Date__c == null) {
                    c.Case_Created_Date__c = ref.Case__r.CreatedDate.date();
                }
            
                if (c.Case_Closed_Date__c != null || c.Case_Created_Date__c != null) {
                    caseMap.put(c.Id, c);
                }
            }
            
            if (isUpdated) {
                referralsToUpdate.add(ref);
            }
        }
		if (!referralsToUpdate.isEmpty()) {
            update referralsToUpdate;
        }
        if (!caseMap.isEmpty()) {
            update caseMap.values();
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('UpdateReferralDatesBatch completed.');
    }
}
