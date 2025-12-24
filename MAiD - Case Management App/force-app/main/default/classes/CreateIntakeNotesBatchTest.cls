@isTest
private class CreateIntakeNotesBatchTest {
    @isTest static void testBatchCreatesNotes() {
        // Create test Intake records
        List<Intake__c> intakes = new List<Intake__c>();
        intakes.add(new Intake__c( Status__c='Closed', ICY_Rationale__c='Rationale 1', Closed_Reason__c='Reason A'));
        intakes.add(new Intake__c( Status__c='Not Started', ICY_Rationale__c='Rationale 2', Closed_Reason__c='Reason B')); // should be ignored
        insert intakes;

        // Verify no notes exist yet
        List<ICY_Notes__c> beforeNotes = [SELECT Id FROM ICY_Notes__c WHERE Intake__c IN :intakes];
        System.assertEquals(0, beforeNotes.size());

        Test.startTest();
            // execute the batch (use small batch size for deterministic behavior in tests)
            Id jobId = Database.executeBatch(new CreateIntakeNotesBatch(), 50);
        Test.stopTest();

        // Verify notes created only for the closed intake
        List<ICY_Notes__c> notes = [SELECT Id, Intake__c, Description__c, Other__c FROM ICY_Notes__c WHERE Intake__c IN :intakes];
        System.assertEquals(1, notes.size(), 'Only one note should be created for the closed intake');
        ICY_Notes__c n = notes[0];
        System.assertEquals(intakes[0].Id, n.Intake__c);
        System.assertEquals('Rationale - Rationale 1', n.Description__c);
        System.assertEquals('Intake Closed Reason - Reason A', n.Other__c);
    }
}