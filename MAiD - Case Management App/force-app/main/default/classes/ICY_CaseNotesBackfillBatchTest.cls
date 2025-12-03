@IsTest
private class ICY_CaseNotesBackfillBatchTest {
    @IsTest
    static void testBackfillReferralAndIntakeNotes() {
        // Create Case
        Case c = new Case(Origin = 'Phone', Status = 'New', Subject = 'Backfill Test');
        insert c;

        // Create related Referral and Intake (1:1 with Case as per requirement)
        Referral__c ref = new Referral__c(Case__c = c.Id);
        insert ref;

        Intake__c intake = new Intake__c(Case__c = c.Id);
        insert intake;

        // Create ICY Notes with Case__c = null but linked to referral/intake
        ICY_Notes__c refNote1 = new ICY_Notes__c(Referral__c = ref.Id);
        ICY_Notes__c refNote2 = new ICY_Notes__c(Referral__c = ref.Id, Note_Source__c = null);
        ICY_Notes__c intakeNote1 = new ICY_Notes__c(Intake__c = intake.Id);
        ICY_Notes__c intakeNote2 = new ICY_Notes__c(Intake__c = intake.Id, Note_Source__c = null);
        insert new List<ICY_Notes__c>{ refNote1, refNote2, intakeNote1, intakeNote2 };

        // Control note already linked to case should remain unchanged
        ICY_Notes__c controlNote = new ICY_Notes__c(Case__c = c.Id, Note_Source__c = 'Other');
        insert controlNote;

        Test.startTest();
        // Run batch with small scope for the test
        Database.executeBatch(new ICY_CaseNotesBackfillBatch(50), 50);
        Test.stopTest();

        // Reload records
        List<ICY_Notes__c> refreshed = [
            SELECT Id, Case__c, Referral__c, Intake__c, Note_Source__c
            FROM ICY_Notes__c
            WHERE Id IN :new List<Id>{ refNote1.Id, refNote2.Id, intakeNote1.Id, intakeNote2.Id, controlNote.Id }
            ORDER BY Id
        ];

        Map<Id, ICY_Notes__c> notesById = new Map<Id, ICY_Notes__c>(refreshed);

        System.assertEquals(c.Id, notesById.get(refNote1.Id).Case__c, 'Referral note 1 Case__c set');
        System.assertEquals('Referral', notesById.get(refNote1.Id).Note_Source__c, 'Referral note 1 source');

        System.assertEquals(c.Id, notesById.get(refNote2.Id).Case__c, 'Referral note 2 Case__c set');
        System.assertEquals('Referral', notesById.get(refNote2.Id).Note_Source__c, 'Referral note 2 source');

        System.assertEquals(c.Id, notesById.get(intakeNote1.Id).Case__c, 'Intake note 1 Case__c set');
        System.assertEquals('Intake', notesById.get(intakeNote1.Id).Note_Source__c, 'Intake note 1 source');

        System.assertEquals(c.Id, notesById.get(intakeNote2.Id).Case__c, 'Intake note 2 Case__c set');
        System.assertEquals('Intake', notesById.get(intakeNote2.Id).Note_Source__c, 'Intake note 2 source');

        // Control note unchanged
        System.assertEquals(c.Id, notesById.get(controlNote.Id).Case__c, 'Control note Case__c unchanged');
        System.assertEquals('Other', notesById.get(controlNote.Id).Note_Source__c, 'Control note source unchanged');
    }
}
