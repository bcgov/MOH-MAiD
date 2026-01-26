@isTest
public class ICY_Referral_ControllerTest {

    @testSetup public static void setup() {

        ICY_ReferralFeatureUtilityTest.setup();

    }

    @isTest static void testMethods(){


       // user u = [Select Id,Name from User Limit 1];
        //System.runAs(u) {
        Referral__c ref = [Select Id,Name,ICY_Personal_Health_Number__c, Priority__c From Referral__c Limit 1];
        ref.ICY_Personal_Health_Number__c = '9999999999';
        ref.Priority__c = 'High';
        update ref;

        Case_Contact__c cs = [Select Id,Name From Case_Contact__c LIMIT 1];
        cs.Id = null;
        Case_Member__c objCaseM = new Case_Member__c();
        objCaseM.Referral__c = ref.id;
        objCaseM.ICY_Status__c = 'Active';
        insert objCaseM;

        ICY_Document__c doc = new ICY_Document__c();
        doc.Referral__c = ref.Id;
        doc.Document_Type__c  = 'Restricted';
        insert doc;

        Test.startTest();
        ICY_Referral_Controller.getPicklistvalues('Case_Member__c','ICY_Category_Assignment__c');
        ICY_Referral_Controller.getRecordTypeId('Case','ICY_Close_Case');
        ICY_Referral_Controller.getRecordTypeName(ref.Id);
        ICY_Referral_Controller.createPrimaryContact(cs,ref.Id);
        ICY_Referral_Controller.isUserPartOfCaseMembers(ref.Id);
        ICY_Referral_Controller.getICYQueueId('Coast');
        ICY_Referral_Controller.checkIfHealthNumberIsUnique('9999999999');
        ICY_Referral_Controller.createICYIntakeRecord(ref.Id);
        Test.stopTest();

        Intake__c intake= [SELECT Id, Name, Referral__c, Priority__c FROM Intake__c WHERE Referral__c = :ref.Id];
        System.assertEquals(ref.Priority__c, intake.Priority__c);

    }
}

   /* @isTest static void testMethods1(){

        user u = [Select Id,Name from User Limit 1];
        System.runAs(u) {
            Referral__c ref = [Select Id,Name,ICY_Personal_Health_Number__c From Referral__c Limit 1];
            ICY_Referral_Controller.createICYIntakeRecord(ref.Id);
        }
    }


}*/