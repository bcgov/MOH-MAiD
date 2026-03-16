@IsTest
public class UpdateReferralOlderRecordsBatchTest {

    @testSetup
    static void setupData() {
		Referral__c referralDup = new Referral__c(
            ICY_Date_of_Referral__c = Date.today(),
            ICY_Geographic_Area__c = 'Central Coast',
            ICY_Referral_Source_Description__c = 'test12',
            ICY_Referral_Source__c = 'Other',
            Individual_First_Name__c = 'dev12',
            Individual_Last_Name__c = 'test13'
        );
        insert referralDup;


        Id caseRtId = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Case'
            AND DeveloperName = 'ICY_Close_Case'
            LIMIT 1
        ].Id;

        Case c = new Case(
            RecordTypeId = caseRtId,
            Status = 'Closed',
            Referral__c = referralDup.Id,
            Origin = 'Phone',
            Subject = 'Closed Case',
            Province_or_Territory_that_issued_PHN__c = '59 - British Columbia',
            PHN__c = '1234567890'
        );
        insert c;
        Intake__c intake = new Intake__c(
            Case__c = c.Id,
            Status__c = 'Closed'
        );
        insert intake;
        
        Referral__c referral = new Referral__c(
            ICY_Date_of_Referral__c = Date.today(),
            ICY_Geographic_Area__c = 'Central Coast',
            ICY_Referral_Source__c = 'Other',
            ICY_Referral_Source_Description__c = 'Test',
            Individual_First_Name__c = 'Dev',
            Individual_Last_Name__c = 'Test',
            Case__c = c.Id,
            Intake__c=intake.id,
            Status__c = 'Closed'
        );
        insert referral;

        Test.setCreatedDate(referral.Id, DateTime.newInstance(2024, 1, 1, 0, 0, 0));
        Test.setCreatedDate(c.Id, DateTime.newInstance(2024, 1, 2, 0, 0, 0));
        Test.setCreatedDate(intake.Id, DateTime.newInstance(2024, 1, 3, 0, 0, 0));
    }

    @IsTest
    static void testUpdateReferralOlderRecordsBatch() {

        Test.startTest();
        Database.executeBatch(new UpdateReferralOlderRecordsBatch(), 200);
        Test.stopTest();

        Referral__c ref = [SELECT Referral_Created_Date__c, Ready_for_Intake_Date__c, Case_Created_Date__c, Closed_Date__c FROM Referral__c WHERE Status__c = 'Closed' LIMIT 1];

        System.assertNotEquals(null, ref.Referral_Created_Date__c);
        System.assertNotEquals(null, ref.Case_Created_Date__c);
        System.assertNotEquals(null, ref.Closed_Date__c);

        
    }
}