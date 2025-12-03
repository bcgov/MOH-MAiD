@isTest
public class ReferralTriggerTest {

    @testSetup
    static void setupData() {
         Id personAccRecordTypeId = YTS_Utility.getRecordTypeIdByDeveloperName('Account', 'ICY_Person_Account');
         //Create ICY Person Account
                Account personAccount = new Account();
                personAccount.RecordTypeId = personAccRecordTypeId;
                personAccount.LastName = 'Test';
                personAccount.FirstName =  'Test';
                personAccount.Individual_Preferred_Name__pc =  'Test';
                
                //Insert Account
                INSERT personAccount;


        // Create Referral record
        Referral__c ref = new Referral__c(
            Type_of_Referral__c = 'General Referral',
            ICY_Date_of_Referral__c = Date.today(),
            Individual_First_Name__c = 'John',
            Individual_Last_Name__c = 'Doe',
            Individual_Preferred_Name__c = 'Johnny',
            Individual_Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            ICY_Personal_Health_Number__c = '1234567890',
            ICY_Referral_Source__c = 'Indigenous services',
            ICY_Geographic_Area__c = 'Central Coast',
            Individual__c = personAccount.Id
        );
        insert ref;

        // Create Intake related to Referral (no Name field used)
        Intake__c intake = new Intake__c(
            Referral__c = ref.Id
        );
        insert intake;

        // Create Case related to Referral
        Id caseRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('ICY_Standard_Case').getRecordTypeId();
        Case c = new Case(
            Referral__c = ref.Id,
            RecordTypeId = caseRtId,
            Status = 'Open',
            Origin = 'Phone'
        );
        insert c;
    }

    @isTest
    static void testReferralFieldPropagation() {
        // Fetch and update the referral
        Referral__c ref = [SELECT Id FROM Referral__c LIMIT 1];
        ref.Individual_First_Name__c = 'Michael';
        ref.Individual_Last_Name__c = 'Smith';
        ref.Individual_Preferred_Name__c = 'Mike';
        ref.Individual_Date_of_Birth__c = Date.newInstance(1985, 12, 25);
        ref.ICY_Personal_Health_Number__c = '9999999999';
        update ref;

        // Validate Referral's searchable DOB
        Referral__c updatedRef = [
            SELECT ICY_Searchable_DOB__c 
            FROM Referral__c 
            WHERE Id = :ref.Id
        ];
        System.assertEquals('1985-12-25', updatedRef.ICY_Searchable_DOB__c);

        // Validate Intake field sync
        Intake__c updatedIntake = [
            SELECT ICY_REF_Indi_First_Name__c,
                   ICY_REF_Indi_Last_Name__c,
                   ICY_REF_Indi_Preferred_Name__c,
                   ICY_REF_Indi_DOB__c,
                   ICY_REF_Personal_Health_Number__c,
                   ICY_Searchable_DOB__c
            FROM Intake__c
            WHERE Referral__c = :ref.Id
            LIMIT 1
        ];

        System.assertEquals('Michael', updatedIntake.ICY_REF_Indi_First_Name__c);
        System.assertEquals('Smith', updatedIntake.ICY_REF_Indi_Last_Name__c);
        System.assertEquals('Mike', updatedIntake.ICY_REF_Indi_Preferred_Name__c);
        System.assertEquals(Date.newInstance(1985, 12, 25), updatedIntake.ICY_REF_Indi_DOB__c);
        System.assertEquals('9999-999-999', updatedIntake.ICY_REF_Personal_Health_Number__c);
        System.assertEquals('1985-12-25', updatedIntake.ICY_Searchable_DOB__c);

        // Validate Case field sync
        Case updatedCase = [
            SELECT ICY_Ref_Ind_First_Name__c,
                   ICY_Ref_Ind_Last_Name__c,
                   ICY_Ref_Ind_Preferred_Name__c,
                   ICY_Ref_Ind_DOB__c,
                   ICY_Ref_Personal_Health_Number__c,
                   ICY_Searchable_DOB__c
            FROM Case
            WHERE Referral__c = :ref.Id
            LIMIT 1
        ];

        System.assertEquals('Michael', updatedCase.ICY_Ref_Ind_First_Name__c);
        System.assertEquals('Smith', updatedCase.ICY_Ref_Ind_Last_Name__c);
        System.assertEquals('Mike', updatedCase.ICY_Ref_Ind_Preferred_Name__c);
        System.assertEquals(Date.newInstance(1985, 12, 25), updatedCase.ICY_Ref_Ind_DOB__c);
        System.assertEquals('9999-999-999', updatedCase.ICY_Ref_Personal_Health_Number__c);
        System.assertEquals('1985-12-25', updatedCase.ICY_Searchable_DOB__c);
    }
}