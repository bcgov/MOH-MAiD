@isTest
public class ICY_AccessCaseControllerTest {
    @TestSetup
    static void makeData(){
        User u = new User(
            //ProfileId = [SELECT Id FROM Profile WHERE Name = 'ICY Administrator'].Id,
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id,
            UserRoleId=[select id from UserRole  where name like '%Admin%' limit 1].Id,
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
        
        Group g1 = new Group(Name='ICYCoast Mountains Team Hazelton', type='Queue');
        insert g1;
        
        QueuesObject q1 = new QueueSObject(QueueID = g1.id, SobjectType = 'Lead');
        insert q1;
        
        GroupMember member = new GroupMember();
        member.UserOrGroupId = u.id;
        member.GroupId = g1.Id;
        insert member;
        
        UserRole urole;
        UserRole urole2;
        System.runAs(u) {
            urole = new UserRole();
            urole.Name = 'Coast Mountains Team Hazelton Program Leader';
            urole.DeveloperName = 'Coast_Mountains_Team_Hazelton_Program_LeaderTest';
            insert urole;
            
            urole2 = new UserRole(RollupDescription ='Customer Manager', Name='Test 1',DeveloperName='Test_123'); 
            urole2.ParentRoleId =urole.Id ;
            insert urole2;
        }
        
        User u2 = new User(
           // ProfileId = [SELECT Id FROM Profile WHERE Name = 'ICY Administrator'].Id,
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
            LocaleSidKey = 'en_US',
            UserRoleId = urole2.Id
        );
        
        insert u2;
        
    }

    static void datasetup(){

        User u = [SELECT ID FROM USER WHERE EMAIL = 'testLead1@gov.bc.ca'];
        User u2 = [select id from user where email='testLead@gov.bc.ca'];


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
        lastname='test',
        ownerId = u2.Id
        );
        insert a;

        case objCase = new case ();
        objCase.Referral__c = RefRecord1.Id;
        objCase.RecordTypeId = YTS_Utility.getRecordTypeIdByDeveloperName('Case', 'ICY_Standard_Case'); 
        objCase.status = 'New';
        objCase.Origin = 'Phone';
        objCase.AccountId = a.Id;
        objCase.OwnerId = u2.Id;
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
    static void getAssignedCaseList_Test(){
        datasetup();
        User u = [SELECT ID FROM USER WHERE EMAIL='testLead@gov.bc.ca'];
        System.runAs(u){
            List<ICY_AccessCaseController.ICY_MyCasesList> result = ICY_AccessCaseController.getAssignedCaseList();
            System.debug(result);
        }
    }
    
}