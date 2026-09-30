@isTest
public class ICY_IntakeFlowHandlerTest {

    
      @testSetup static void testSetup(){
        ICY_ReferralFeatureUtilityTest.setup();
      }
    
    @isTest static void testSendClosedIntakeEmailNotificationToLead(){
        Intake__c intake = [Select Id,Name,Referral__c,Referral__r.ICY_Geographic_Area__c,ICY_Who_Is_Doing__c From Intake__c LIMIT 1];
        List<Intake__c> intakeList = new List<Intake__c>();
        intake.ICY_Who_Is_Doing__c = userinfo.getUserId();
        intakeList.add(intake);
        Test.startTest();
        ICY_IntakeFlowHandler.sendClosedIntakeEmailNotificationToLead(intakeList);
        Test.stopTest();
    }
}