@isTest
public class ICY_CaseMember_Controller_Test {

    @TestSetup 
    static void makeData(){
        User u = new User(
           // ProfileId = [SELECT Id FROM Profile WHERE Name = 'ICY Administrator'].Id,
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id,
            LastName = 'last',
            Email = 'testLead@gov.bc.ca',
            Username = 'testLead@gov.bc.ca' + System.currentTimeMillis(),
            CompanyName = 'TEST',
            Title = 'title',
            Alias = 'alias',
            TimeZoneSidKey = 'America/Los_Angeles',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US'
        );
        
        insert u;

        User u2 = new User(
          //  ProfileId = [SELECT Id FROM Profile WHERE Name = 'ICY Administrator'].Id,
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id,
            LastName = 'last',
            Email = 'testLead1@gov.bc.ca',
            Username = 'testLead1@gov.bc.ca' + System.currentTimeMillis(),
            CompanyName = 'TEST',
            Title = 'title',
            Alias = 'alias',
            TimeZoneSidKey = 'America/Los_Angeles',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US'
        );
        
        insert u2;

        User u3 = new User(
            //ProfileId = [SELECT Id FROM Profile WHERE Name = 'ICY Clinical Team Member'].Id,
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id,
            LastName = 'last',
            Email = 'testLead2@gov.bc.ca',
            Username = 'testLead2@gov.bc.ca' + System.currentTimeMillis(),
            CompanyName = 'TEST',
            Title = 'title',
            Alias = 'alias',
            TimeZoneSidKey = 'America/Los_Angeles',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US'
        );
        
        insert u3;
 
        Referral__c RefRecord1 = new Referral__c();
        RefRecord1.Type_of_Referral__c = 'Organizational Referral';
        RefRecord1.Referring_Organization__c = 'Health Authority';
        RefRecord1.Individual_First_Name__c = 'Test';
        RefRecord1.Individual_Middle_Name__c = 'Middle';
        RefRecord1.Individual_Last_Name__c = 'Referral';
        RefRecord1.Individual_Preferred_Name__c = 'Ref';
        RefRecord1.Individual_Date_of_Birth__c = System.today();
        RefRecord1.Individual_Gender__c = 'Male';
        RefRecord1.Individual_Pronouns__c = 'He';
        RefRecord1.EIS_Region__c = 'Northern Region';
        RefRecord1.EIS_Location__c = 'Peace North';
        RefRecord1.Mailing_Address_same_as_Physical_Address__c = true;
        RefRecord1.Physical_Address_Line_1__c = 'Test';
        RefRecord1.Physical_Address_Postal_Code__c = 'M1J 2J1';
        RefRecord1.Physical_Address_Province__c = 'BC';
        RefRecord1.Physical_Address_City__c = 'Vancouver';
        RefRecord1.Mailing_Address_Line_1__c = 'Test';
        RefRecord1.Mailing_Address_City__c = 'Vancouver';
        RefRecord1.Mailing_Address_Postal_Code__c = 'M1J 2J1';
        RefRecord1.Mailing_Address_Province__c = 'BC';
        RefRecord1.Preferred_method_of_contact__c = 'Phone';
        RefRecord1.Individual_Home_Phone_Number__c = '2223334444';
        RefRecord1.Individual_Cell_Phone_Number__c = '3334445555';
        RefRecord1.Individual_Email_Address__c = '';
        RefRecord1.Language_in_the_Home__c = 'Mandarin';
        RefRecord1.Other_Language__c = 'Hindi';
        RefRecord1.Primary_Contact_Is_Individual_Indicator__c = false;
        RefRecord1.Is_Individual_Attending_School__c = 'Yes';
        RefRecord1.Current_School__c = 'Test School';
        RefRecord1.Who_does_the_youth_live_with__c = 'Family';
        RefRecord1.Is_stable_housing_a_concern__c = '';
        RefRecord1.Explain_housing_concern__c = 'Test Test';
        RefRecord1.Special_limitations_hearing_sight_mob__c = 'Test';
        RefRecord1.What_services_they_are_waiting_for__c = 'Test Services';
        RefRecord1.DAA_or_other_cultural_or_spiritual_repre__c = 'Test';
        RefRecord1.Referral_Notes__c = 'This is a test note.';
        RefRecord1.ICY_Show_Banner__c = TRUE;
        RefRecord1.ICY_Geographic_Area__c = 'Coast Mountains Team Hazelton';
        RefRecord1.RecordTypeId = YTS_Utility.getRecordTypeIdByDeveloperName('Referral__c', 'ICY_General'); 
        insert RefRecord1;
        
        Intake__c intake = new Intake__c();
        intake.Referral__c = RefRecord1.Id;
        intake.RecordTypeId = YTS_Utility.getRecordTypeIdByDeveloperName('Intake__c', 'ICY_Intake'); 
        insert intake;

        Account a = new Account(
            recordTypeId = YTS_Utility.getRecordTypeIdByDeveloperName('Account', 'ICY_Person_Account'),
            FirstName = 'test',
            lastname='test'
        );
        insert a;

        case objCase = new case ();
        objCase.Referral__c = RefRecord1.Id;
        objCase.RecordTypeId = YTS_Utility.getRecordTypeIdByDeveloperName('Case', 'ICY_Standard_Case'); 
        objCase.status = 'New';
        objCase.Origin = 'Phone';
        objCase.AccountId = a.Id;
        insert objCase;

        RefRecord1.Case__c = objCase.Id;
        intake.Case__c = objCase.id;

        Update RefRecord1;
        Update intake;


        Case_Member__c cm = new Case_Member__c(
            ICY_Case__c = objCase.Id,
            ICY_Category_Assignment__c = 'MRTM',
            ICY_Status__c = 'Active',
            ICY_User__c = u.Id,
            Referral__c = RefRecord1.Id
        );

        Case_Member__c cm1 = new Case_Member__c(
            ICY_Case__c = objCase.Id,
            ICY_Category_Assignment__c = 'Consulting',
            ICY_Status__c = 'Active',
            ICY_User__c = u2.Id,
            Referral__c = RefRecord1.Id
        );

        INSERT cm;
        INSERT cm1;
    }

    @isTest
    private static void getAllCaseTeamMembers_test1(){
        Case c = [SELECT ID FROM CASE LIMIT 1];
        Test.startTest();
        List<ICY_CaseMember_Controller.CaseMember> result = ICY_CaseMember_Controller.getAllCaseTeamMembers(c.Id);
        Test.stopTest();
        System.assertEquals(2, result.size());
    }

    @isTest
    private static void getAllCaseTeamMembers_test2(){
        Referral__c c = [SELECT ID FROM Referral__c LIMIT 1];
        Test.startTest();
        List<ICY_CaseMember_Controller.CaseMember> result = ICY_CaseMember_Controller.getAllCaseTeamMembers(c.Id);
        Test.stopTest();
        System.assertEquals(2, result.size());
    }


    @isTest
    private static void showSelfAccessButton_Test(){
        Referral__c c = [SELECT ID FROM Referral__c LIMIT 1];
        Boolean result = ICY_CaseMember_Controller.showSelfAccessButton(c.Id);
        System.assert(!result);
        User u = [SELECT ID FROM USER where EMAIL = 'testLead1@gov.bc.ca' LIMIT 1];
        System.runAs(u){
            Boolean result2 = ICY_CaseMember_Controller.showSelfAccessButton(c.Id);
        }
        User u2 = [SELECT ID FROM USER WHERE EMAIL = 'testLead2@gov.bc.ca' LIMIT 1];
        System.runAs(u2){
            Boolean result2 = ICY_CaseMember_Controller.showSelfAccessButton(c.Id);
        }
    }

    @isTest
    private static void upsertCaseMember_test(){
        Referral__c c = [SELECT ID FROM Referral__c LIMIT 1];
        User u2 = [SELECT ID FROM USER WHERE EMAIL = 'testLead2@gov.bc.ca' LIMIT 1];
        System.runAs(u2){
            Case_Member__c cm = new Case_Member__c(
                    Referral__c = c.Id,
                    ICY_Category_Assignment__c = 'MRTM',
                    ICY_Status__c = 'Active'
                );
            String result = ICY_CaseMember_Controller.upsertCaseMember(cm, c.Id, null, true);
        }   
    }

    @isTest
    private static void revokeTeamMemberAccess_test(){
        Case_Member__c c = [SELECT ID FROM Case_Member__c LIMIT 1];
        ICY_CaseMember_Controller.revokeCaseTeamMemberAccess(c.Id);
    }

    @isTest
    private static void delete_TeamMember_test(){
        Case_Member__c c = [SELECT ID FROM Case_Member__c LIMIT 1];
       Database.delete(c,false);
    }
}