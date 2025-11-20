@isTest
private class CreateCaseNotesBatchTest {
    @isTest static void testBatchCreatesNotes() {
        // Create test Intake records
        List<Case> cases = new List<Case>();
        cases.add(new Case( Status='Closed', ICY_Rationale__c='Rationale 1', Case_Closed_Reason__c='Reason A'));
        cases.add(new Case( Status='Not Started', ICY_Rationale__c='Rationale 2', Case_Closed_Reason__c='Reason B')); // should be ignored
        insert cases;

        // Verify no notes exist yet
        List<ICY_Notes__c> beforeNotes = [SELECT Id FROM ICY_Notes__c WHERE Case__c IN :cases];
        System.assertEquals(0, beforeNotes.size());

        Test.startTest();
            // execute the batch (use small batch size for deterministic behavior in tests)
            Id jobId = Database.executeBatch(new CreateCaseNotesBatch(), 50);
        Test.stopTest();

        // Verify notes created only for the closed Cases
        List<ICY_Notes__c> notes = [SELECT Id, Case__c, Description__c, Other__c FROM ICY_Notes__c WHERE Case__c IN :cases];
        System.assertEquals(1, notes.size(), 'Only one note should be created for the closed case');
        ICY_Notes__c n = notes[0];
        System.assertEquals(cases[0].Id, n.Case__c);
        System.assertEquals('Rationale 1', n.Description__c);
        System.assertEquals('Reason A', n.Other__c);
    }
}