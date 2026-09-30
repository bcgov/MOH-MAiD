public with sharing class ICY_IntakeNotesHandler {
    /**
     * After-update handler: when Intake__c.Case__c is populated (changed from null),
     * set Case__c on ICY_Notes__c records related to that Intake (by Intake__c lookup) where Case__c is null.
     */
    public static void afterUpdate(List<Intake__c> newList, Map<Id, Intake__c> oldMap) {
        if (newList == null || newList.isEmpty()) return;

        // Collect Intake Ids that transitioned from null Case__c to non-null Case__c
        Set<Id> intakeIdsNeedingUpdate = new Set<Id>();
        Map<Id, Id> intakeToCase = new Map<Id, Id>(); // Intake Id -> Case Id

        for (Intake__c rec : newList) {
            Intake__c oldRec = oldMap != null ? oldMap.get(rec.Id) : null;
            Boolean oldWasNull = (oldRec == null) || (oldRec.Case__c == null);
            if (oldWasNull && rec.Case__c != null) {
                intakeIdsNeedingUpdate.add(rec.Id);
                intakeToCase.put(rec.Id, rec.Case__c);
            }
        }
        if (intakeIdsNeedingUpdate.isEmpty()) return;

        // Query notes linked to those Intake records where Case__c is still null
        List<ICY_Notes__c> notes = [
            SELECT Id, Case__c, Intake__c
            FROM ICY_Notes__c
            WHERE Intake__c IN :intakeIdsNeedingUpdate
              AND Case__c = NULL
            LIMIT 10000
        ];

        for (ICY_Notes__c note : notes) {
            Id caseId = intakeToCase.get(note.Intake__c);
            if (caseId != null) {
                note.Case__c = caseId;
                note.Note_Source__c='Intake';
            }
        }

        if (!notes.isEmpty()) {
            update notes;
        }
    }
}
