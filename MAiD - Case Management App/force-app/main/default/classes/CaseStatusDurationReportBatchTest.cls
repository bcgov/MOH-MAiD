@IsTest
public class CaseStatusDurationReportBatchTest {

    @testSetup
    static void testData() {

        Referral__c referral = new Referral__c(
            ICY_Date_of_Referral__c = Date.today(),
            ICY_Geographic_Area__c = 'Central Coast',
            ICY_Referral_Source_Description__c = 'testetets',
            ICY_Referral_Source__c = 'Other',
            Individual_First_Name__c = 'dev',
            Individual_Last_Name__c = 'test'
        );
        insert referral;

        Id standardCaseId = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Case'
            AND DeveloperName = 'ICY_Standard_Case'
            LIMIT 1
        ].Id;
        Id closeCaseId = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Case'
            AND DeveloperName = 'ICY_Close_Case'
            LIMIT 1
        ].Id;

        List<Case> cases = new List<Case>();

        cases.add(new Case(
            RecordTypeId = standardCaseId,
            Status = 'Awaiting Forms',
            Referral__c = referral.Id,
            Origin = 'Phone',
            Subject = 'Open Case',
            Province_or_Territory_that_issued_PHN__c = '59 - British Columbia',
            PHN__c = '1234567890'
        ));

        cases.add(new Case(
            RecordTypeId = closeCaseId,
            Referral__c = referral.Id,
            Case_Closed_Date__c = null,
            Status = 'Ready for CC Review',
            Origin = 'Email',
            Subject = 'Closed ',
            Province_or_Territory_that_issued_PHN__c = '59 - British Columbia',
            PHN__c = '0987654321'
        ));

        cases.add(new Case(
            RecordTypeId = standardCaseId,
            Status = 'Ready for CC Review',
            Referral__c = referral.Id,
            Origin = 'Web',
            Subject = 'Already Updated Case',
            Case_Created_Date__c = Date.today().addDays(-5),
            Case_Closed_Date__c  = Date.today().addDays(-1),
            Province_or_Territory_that_issued_PHN__c = '59 - British Columbia',
            PHN__c = '1112223333'
        ));

        insert cases;
        for (Case c : cases) {
            Test.setCreatedDate(c.Id, DateTime.newInstance(2024, 1, 1, 0, 0, 0));
        }
    }

    @IsTest
    static void testBatchUpdatesCreatedAndClosedDates() {

        Test.startTest();
        Database.executeBatch(new CaseStatusDurationReportBatch(), 200);
        Test.stopTest();

        Case openCase = [
            SELECT Case_Created_Date__c, Case_Closed_Date__c
            FROM Case
            WHERE Status = 'Awaiting Forms'
            LIMIT 1
        ];
        System.assertNotEquals(null, openCase.Case_Created_Date__c);
    }
}