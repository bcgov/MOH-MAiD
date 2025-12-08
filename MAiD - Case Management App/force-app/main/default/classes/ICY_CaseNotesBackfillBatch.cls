public with sharing class ICY_CaseNotesBackfillBatch implements Database.Batchable<SObject>, Database.Stateful {
    public Integer scopeSize { get; private set; }

    public ICY_CaseNotesBackfillBatch(Integer scopeSize) {
        this.scopeSize = (scopeSize == null || scopeSize <= 0) ? 200 : Math.min(scopeSize, 2000);
    }
    public ICY_CaseNotesBackfillBatch() {
        this(200);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Process all Cases. 
        return Database.getQueryLocator([
            SELECT Id
            FROM Case
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Case> scope) {
        if (scope.isEmpty()) return;

        Set<Id> caseIds = new Set<Id>();
        for (Case c : scope) caseIds.add(c.Id);

        // Each Case has exactly one Referral__c and one Intake__c 
        // Query referrals by Case
        Map<Id, Referral__c> caseIdToReferral = new Map<Id, Referral__c>();
        for (Referral__c ref : [
            SELECT Id, Case__c
            FROM Referral__c
            WHERE Case__c IN :caseIds
        ]) {
            if (ref.Case__c != null && !caseIdToReferral.containsKey(ref.Case__c)) {
                caseIdToReferral.put(ref.Case__c, ref);
            }
        }

        // Query intakes by Case
        Map<Id, Intake__c> caseIdToIntake = new Map<Id, Intake__c>();
        for (Intake__c intake : [
            SELECT Id, Case__c
            FROM Intake__c
            WHERE Case__c IN :caseIds
        ]) {
            if (intake.Case__c != null && !caseIdToIntake.containsKey(intake.Case__c)) {
                caseIdToIntake.put(intake.Case__c, intake);
            }
        }

        Set<Id> referralIds = new Set<Id>();
        for (Referral__c r : caseIdToReferral.values()) referralIds.add(r.Id);

        Set<Id> intakeIds = new Set<Id>();
        for (Intake__c i : caseIdToIntake.values()) intakeIds.add(i.Id);

        // Reverse maps for quick lookup
        Map<Id, Id> referralIdToCaseId = new Map<Id, Id>();
        for (Id cId : caseIdToReferral.keySet()) {
            referralIdToCaseId.put(caseIdToReferral.get(cId).Id, cId);
        }
        Map<Id, Id> intakeIdToCaseId = new Map<Id, Id>();
        for (Id cId : caseIdToIntake.keySet()) {
            intakeIdToCaseId.put(caseIdToIntake.get(cId).Id, cId);
        }

        List<ICY_Notes__c> toUpdate = new List<ICY_Notes__c>();

        if (!referralIds.isEmpty()) {
            for (ICY_Notes__c n : [
                SELECT Id, Case__c, Referral__c, Note_Source__c
                FROM ICY_Notes__c
                WHERE Case__c = NULL
                AND Referral__c IN :referralIds
            ]) {
                Id caseId = referralIdToCaseId.get(n.Referral__c);
                if (caseId != null) {
                    n.Case__c = caseId;
                    n.Note_Source__c = 'Referral';
                    toUpdate.add(n);
                }
            }
        }

        if (!intakeIds.isEmpty()) {
            for (ICY_Notes__c n : [
                SELECT Id, Case__c, Intake__c, Note_Source__c
                FROM ICY_Notes__c
                WHERE Case__c = NULL
                AND Intake__c IN :intakeIds
            ]) {
                Id caseId = intakeIdToCaseId.get(n.Intake__c);
                if (caseId != null) {
                    n.Case__c = caseId;
                    n.Note_Source__c = 'Intake';
                    toUpdate.add(n);
                }
            }
        }

        System.debug('ICY_Notes__c to update :' + toUpdate);
        if (!toUpdate.isEmpty()) {
            Database.SaveResult[] srList = Database.update(toUpdate, false);
            for (Integer i = 0; i < srList.size(); i++) {
                if (!srList[i].isSuccess()) {
                    for (Database.Error e : srList[i].getErrors()) {
                        System.debug(LoggingLevel.WARN,
                            'Failed to update ICY_Notes__c Id=' + toUpdate[i].Id + ' msg=' + e.getMessage());
                    }
                }
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        // Optional: summary logic or logging
    }
}
