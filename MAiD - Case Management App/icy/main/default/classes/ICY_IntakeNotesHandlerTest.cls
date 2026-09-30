@IsTest
private class ICY_IntakeNotesHandlerTest {
     @testSetup static void testSetup(){
        ICY_ReferralFeatureUtilityTest.setup();
        intake__c intake = [Select Id From Intake__c LIMIT 1];
         // Create ICY Note linked to Intake, with null Case__c (should be updated when Intake.Case__c is populated)
        ICY_Notes__c noteLinkedToIntake = new ICY_Notes__c(Intake__c = intake.Id);
        insert noteLinkedToIntake;
      }

    @IsTest
    static void testIntakeCaseLinkUpdatesNotes() {
        Case  cs = [Select Id From Case  LIMIT 1];
        intake__c intake = [Select Id From Intake__c LIMIT 1];

        Test.startTest();
        // Populate Intake.Case__c to trigger Intake after update logic
        intake.Case__c = cs.Id;
        update intake;
        Test.stopTest();
        ICY_Notes__c nte = [Select Id from ICY_Notes__c LIMIT 1];

        // Verify the note is updated with Case__c
        ICY_Notes__c noteLinkedToIntake = [
            SELECT Id, Case__c, Intake__c
            FROM ICY_Notes__c
            WHERE Id = :nte.Id
        ];
        System.assertEquals(cs.Id, noteLinkedToIntake.Case__c, 'ICY Note linked to Intake should be stamped with Intake.Case__c');
    }
}
