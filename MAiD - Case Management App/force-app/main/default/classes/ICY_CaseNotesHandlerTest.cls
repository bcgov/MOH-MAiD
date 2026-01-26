@IsTest
private class ICY_CaseNotesHandlerTest {
     @testSetup static void testSetup(){
        ICY_ReferralFeatureUtilityTest.setup();
      }

    @IsTest
    static void testReferralBasedNotesUpdate() {       
        Referral__c ref = [Select Id From Referral__c LIMIT 1];
         // Create ICY Note linked to Intake, with null Case__c (should be updated when Intake.Case__c is populated)
        ICY_Notes__c n1 = new ICY_Notes__c(Referral__c =  ref.Id);
        ICY_Notes__c n2 = new ICY_Notes__c(Referral__c =  ref.Id);
             
        insert new List<ICY_Notes__c>{ n1, n2 };
     
        // Re-query notes
        n1 = [SELECT Id, Case__c, Referral__c FROM ICY_Notes__c WHERE Id = :n1.Id];
        n2 = [SELECT Id, Case__c, Referral__c FROM ICY_Notes__c WHERE Id = :n2.Id];
     
        System.assertEquals(ref.Id, n1.Referral__c);
     
    }

}
