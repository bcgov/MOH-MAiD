@IsTest
public class IntakeStatusDurationReportBatchTest {

    @testSetup
    static void testData() {
        Referral__c referral = new Referral__c(
            ICY_Date_of_Referral__c = Date.today(),
            ICY_Geographic_Area__c = 'Central Coast',
            ICY_Referral_Source_Description__c = 'test',
            ICY_Referral_Source__c = 'Other',
            Individual_First_Name__c = 'dev',
            Individual_Last_Name__c = 'test'
        );
        insert referral;

        Id standardCaseRtId = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Case'
            AND DeveloperName = 'ICY_Standard_Case'
            LIMIT 1
        ].Id;

        Id closeCaseRtId = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Case'
            AND DeveloperName = 'ICY_Close_Case'
            LIMIT 1
        ].Id;

       
        Case openCase = new Case(
            RecordTypeId = standardCaseRtId,
            Status = 'Open',
            Referral__c = referral.Id,
            Origin = 'Phone',
            Subject = 'Open Case',
            Province_or_Territory_that_issued_PHN__c = '59 - British Columbia',
            PHN__c = '1234567890'
        );

        Case closedCase = new Case(
            RecordTypeId = closeCaseRtId,
            Status = 'Closed',
            Referral__c = referral.Id,
            Origin = 'Email',
            Subject = 'Closed Case',
            Province_or_Territory_that_issued_PHN__c = '59 - British Columbia',
            PHN__c = '0987654321'
        );

        insert new List<Case>{ openCase, closedCase };
            
        Test.setCreatedDate(openCase.Id, DateTime.newInstance(2024, 1, 1, 0, 0, 0));
        Test.setCreatedDate(closedCase.Id, DateTime.newInstance(2024, 1, 1, 0, 0, 0));
        
        Intake__c intake1 = new Intake__c(
            Case__c = openCase.Id,
            Status__c = 'Not Started'
        );

        Intake__c intake2 = new Intake__c(
            Case__c = closedCase.Id,
            Status__c = 'Not Started'
        );

        Intake__c intake3 = new Intake__c(
            Case__c = closedCase.Id,
            Status__c = 'Closed'
        );

        insert new List<Intake__c>{ intake1, intake2, intake3 };

        for (Intake__c i : new List<Intake__c>{ intake1, intake2, intake3 }) {
            Test.setCreatedDate(i.Id, DateTime.newInstance(2024, 1, 2, 0, 0, 0));
        }
    }

    @IsTest
    static void testBatchUpdatesIntakeDates() {

        Test.startTest();
        Database.executeBatch(new IntakeStatusDurationReportBatch(), 200);
        Test.stopTest();

        List<Intake__c> intakes = [
            SELECT
                Not_Started_Date__c,
                Complete_Date__c,
                ICY_Intake_Close_Date__c,
                Status__c
            FROM Intake__c
        ];

        for (Intake__c intake : intakes) {

            System.assertNotEquals(null, intake.Not_Started_Date__c, 'Not_Started_Date__c should be populated');
            System.assertNotEquals( null, intake.Complete_Date__c);

        }
    }
}