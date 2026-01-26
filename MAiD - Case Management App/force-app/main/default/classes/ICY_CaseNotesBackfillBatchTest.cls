@IsTest
private class ICY_CaseNotesBackfillBatchTest {
    @IsTest
    static void testBackfillReferralAndIntakeNotes() {
        ICY_ReferralFeatureUtilityTest.setup();

        Referral__c RefRecord = [SELECT id from Referral__c LIMIT 1];
        Intake__c IntRecord = [SELECT id from Intake__c LIMIT 1];

        Case caseRecord = [SELECT id from Case LIMIT 1];
        IntRecord.Case__c=  caseRecord.Id;
        update IntRecord;

        ICY_Notes__c refNote2 = new ICY_Notes__c(Referral__c = RefRecord.Id, Note_Source__c = null);
       
        ICY_Notes__c intakeNote2 = new ICY_Notes__c(Intake__c = IntRecord.Id, Note_Source__c = null);
        insert new List<ICY_Notes__c>{ refNote2,intakeNote2 };

        ICY_Notes__c controlNote = new ICY_Notes__c(Case__c = caseRecord.Id);
        insert controlNote;

        Test.startTest();
        // Run batch with small scope for the test
        Database.executeBatch(new ICY_CaseNotesBackfillBatch(50), 50);
        Test.stopTest();

        // Reload records
        List<ICY_Notes__c> refreshed = [
            SELECT Id, Case__c, Referral__c, Intake__c, Note_Source__c
            FROM ICY_Notes__c
            WHERE Id IN :new List<Id>{ refNote2.Id, intakeNote2.Id, controlNote.Id }
            ORDER BY Id
        ];

        Map<Id, ICY_Notes__c> notesById = new Map<Id, ICY_Notes__c>(refreshed);

        System.assertEquals(caseRecord.Id, notesById.get(refNote2.Id).Case__c, 'Referral note 2 Case__c set');
        System.assertEquals('Referral', notesById.get(refNote2.Id).Note_Source__c, 'Referral note 2 source');
        System.assertEquals(caseRecord.Id, notesById.get(intakeNote2.Id).Case__c, 'Intake note 2 Case__c set');
        System.assertEquals('Intake', notesById.get(intakeNote2.Id).Note_Source__c, 'Intake note 2 source');
        System.assertEquals(caseRecord.Id, notesById.get(controlNote.Id).Case__c, 'Control note Case__c unchanged');
    }
}
