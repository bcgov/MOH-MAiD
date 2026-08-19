@isTest
public class ICY_Referral_ControllerTest {

    @testSetup public static void setup() {

        ICY_ReferralFeatureUtilityTest.setup();

    }
	
    @isTest static void testMethods(){
        Referral__c ref = new Referral__c();
        ref.ICY_Personal_Health_Number__c = '9999999999';
        ref.Priority__c = 'High';
        insert ref;
    
        //Re-query because Referral automation may format/update the PHN
        ref = [
            SELECT Id, ICY_Personal_Health_Number__c, Priority__c
            FROM Referral__c
            WHERE Id = :ref.Id
        ];
    
        Case_Contact__c cs = [Select Id,Name From Case_Contact__c LIMIT 1];
        cs.Id = null;
        Case_Member__c objCaseM = new Case_Member__c();
        objCaseM.Referral__c = ref.Id;
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
    
        String contactId =
            ICY_Referral_Controller.createPrimaryContact(
                cs,
                ref.Id
            );
    
        ICY_Referral_Controller.isUserPartOfCaseMembers(ref.Id);
        ICY_Referral_Controller.getICYQueueId('Coast');
    
        Boolean duplicatePHN =
            ICY_Referral_Controller.checkIfHealthNumberIsUnique(
                ref.ICY_Personal_Health_Number__c
            );
    
        String intakeId =
            ICY_Referral_Controller.createICYIntakeRecord(ref.Id);
    
        Test.stopTest();
    
        System.assertEquals(
            false,
            duplicatePHN,
            'PHN stored on the existing Referral should not be unique.'
        );
    
        System.assertNotEquals(null, intakeId);
    
        Intake__c intake = [
            SELECT Id, Referral__c, Priority__c
            FROM Intake__c
            WHERE Id = :intakeId
        ];
    
        System.assertEquals(ref.Id, intake.Referral__c);
        System.assertEquals(ref.Priority__c, intake.Priority__c);
    
        ICY_Document__c updatedDoc = [
            SELECT Id, Intake__c
            FROM ICY_Document__c
            WHERE Id = :doc.Id
        ];
    
        System.assertEquals(intake.Id, updatedDoc.Intake__c);
    
        Case_Contact__c updatedContact = [
            SELECT Id, Intake__c
            FROM Case_Contact__c
            WHERE Id = :contactId
        ];
    
        System.assertEquals(intake.Id, updatedContact.Intake__c);
    }
    
    @isTest
    static void testRemovePreviousAreaIntakeShare(){

        Id queueId =
            ICY_Referral_Controller.getICYQueueId('Coast');

        Referral__c ref = new Referral__c();
        ref.ICY_Personal_Health_Number__c = '7777777777';
        ref.Priority__c = 'High';
        ref.OwnerId = queueId;
        insert ref;

        String intakeId =
            ICY_Referral_Controller.createICYIntakeRecord(ref.Id);

        Intake__c intake = [
            SELECT Id,
                   Referral__c,
                   OwnerId
            FROM Intake__c
            WHERE Id = :intakeId
        ];

        Intake__Share intakeShare = new Intake__Share(
            ParentId = intake.Id,
            UserOrGroupId = UserInfo.getUserId(),
            AccessLevel = 'Edit',
            RowCause =
                Schema.Intake__Share.RowCause.Case_Team_Member_Share__c
        );

        insert intakeShare;

        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM Intake__Share
                WHERE ParentId = :intake.Id
                AND RowCause =
                    'Case_Team_Member_Share__c'
            ]
        );

        Test.startTest();

        ICY_Referral_Controller.removePreviousAreaIntakeShare(
            new Set<Id>{ref.Id}
        );

        Test.stopTest();

        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM Intake__Share
                WHERE ParentId = :intake.Id
                AND RowCause =
                    'Case_Team_Member_Share__c'
            ]
        );
    }


    @isTest
    static void testUpdateIntakeOwnerToReferralOwner(){

        Referral__c ref = new Referral__c();
        ref.ICY_Personal_Health_Number__c = '6666666666';
        ref.Priority__c = 'High';
        insert ref;

        String intakeId =
            ICY_Referral_Controller.createICYIntakeRecord(ref.Id);

        Id newQueueId =
            ICY_Referral_Controller.getICYQueueId('Coast');

        ref.OwnerId = newQueueId;
        update ref;

        Test.startTest();

        ICY_Referral_Controller.removePreviousAreaIntakeShare(
            new Set<Id>{ref.Id}
        );

        Test.stopTest();

        Intake__c updatedIntake = [
            SELECT Id, OwnerId
            FROM Intake__c
            WHERE Id = :intakeId
        ];

        System.assertEquals(
            newQueueId,
            updatedIntake.OwnerId,
            'Intake Owner should match Referral Owner.'
        );
    }


    @isTest
    static void testRemovePreviousAreaIntakeShareNoIntake(){

        Referral__c ref = new Referral__c();
        ref.ICY_Personal_Health_Number__c = '5555555555';
        ref.Priority__c = 'High';
        insert ref;

        Test.startTest();

        ICY_Referral_Controller.removePreviousAreaIntakeShare(
            new Set<Id>{ref.Id}
        );

        Test.stopTest();

        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM Intake__c
                WHERE Referral__c = :ref.Id
            ]
        );
    }


    @isTest
    static void testRemovePreviousAreaIntakeShareEmptyInput(){

        Test.startTest();

        ICY_Referral_Controller.removePreviousAreaIntakeShare(null);
        ICY_Referral_Controller.removePreviousAreaIntakeShare(
            new Set<Id>()
        );

        Test.stopTest();

        System.assert(true);
    }


    @isTest
    static void testCreateIntakeException(){

        Boolean exceptionThrown = false;

        Test.startTest();

        try{
            ICY_Referral_Controller.createICYIntakeRecord(null);
        }catch(Exception e){
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown,
            'Invalid Referral should result in an exception.'
        );
    }
    
    @isTest
    static void testUniqueHealthNumber(){
    
        Referral__c ref = new Referral__c();
        ref.ICY_Personal_Health_Number__c = '9999999998';
        ref.Priority__c = 'High';
        insert ref;
    
        //Re-query actual PHN after Referral automation has executed
        ref = [
            SELECT Id, ICY_Personal_Health_Number__c
            FROM Referral__c
            WHERE Id = :ref.Id
        ];
    
        Test.startTest();
    
        Boolean duplicateResult =
            ICY_Referral_Controller.checkIfHealthNumberIsUnique(
                ref.ICY_Personal_Health_Number__c
            );
    
        Boolean uniqueResult =
            ICY_Referral_Controller.checkIfHealthNumberIsUnique(
                '1234567890'
            );
    
        Test.stopTest();
    
        System.assertEquals(
            false,
            duplicateResult,
            'Existing Referral PHN should return false.'
        );
    
        System.assertEquals(
            true,
            uniqueResult,
            'A PHN that does not exist should return true.'
        );
    }
}