@isTest
public class ICY_IntegratedCarePlanCtrlTest {

    @testSetup static void testSetup(){
        List<user> lstuser = new List<User>();
        User u = new User(
          //  ProfileId = [SELECT Id FROM Profile WHERE Name = 'ICY Program Leader'].Id,
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
            //UserRoleId = r.Id
        );
        lstuser.add(u);

        User u2 = new User(
            //ProfileId = [SELECT Id FROM Profile WHERE Name = 'ICY Administrator'].Id,
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id,
            LastName = 'last',
            Email = 'testLead2@gov.bc.ca',
            Username = 'testLead2@gov.bc.ca1' + System.currentTimeMillis(),
            CompanyName = 'TEST',
            Title = 'title',
            Alias = 'alias',
            TimeZoneSidKey = 'America/Los_Angeles',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US'
            //UserRoleId = r.Id
        );
        lstuser.add(u2);

        insert lstuser;

        UserRole urole;

            case objCase = new case ();
            objCase.status = 'New';
            objCase.Origin = 'Phone';
            objCase.RecordTypeId = YTS_Utility.getRecordTypeIdByDeveloperName('Case', 'ICY_Standard_Case');
            insert objCase;

           	Referral__c RefRecord = new Referral__c();
            RefRecord.Type_of_Referral__c = 'Organizational Referral';
            RefRecord.Referring_Organization__c = 'Health Authority';
            RefRecord.Individual_First_Name__c = 'Test';
            RefRecord.Individual_Middle_Name__c = 'Middle';
            RefRecord.Individual_Last_Name__c = 'Referral';
            RefRecord.Individual_Preferred_Name__c = 'Ref';
            RefRecord.Individual_Date_of_Birth__c = System.today();
            RefRecord.Individual_Gender__c = 'Male';
            RefRecord.Individual_Pronouns__c = 'He';
            RefRecord.EIS_Region__c = 'Northern Region';
            RefRecord.EIS_Location__c = 'Peace North';
            RefRecord.Mailing_Address_same_as_Physical_Address__c = true;
            RefRecord.Physical_Address_Line_1__c = 'Test';
            RefRecord.Physical_Address_Postal_Code__c = 'M1J 2J1';
            RefRecord.Physical_Address_Province__c = 'BC';
            RefRecord.Physical_Address_City__c = 'Vancouver';
            RefRecord.Mailing_Address_Line_1__c = 'Test';
            RefRecord.Mailing_Address_City__c = 'Vancouver';
            RefRecord.Mailing_Address_Postal_Code__c = 'M1J 2J1';
            RefRecord.Mailing_Address_Province__c = 'BC';
            RefRecord.Preferred_method_of_contact__c = 'Phone';
            RefRecord.Individual_Home_Phone_Number__c = '2223334444';
            RefRecord.Individual_Cell_Phone_Number__c = '3334445555';
            RefRecord.Individual_Email_Address__c = '';
            RefRecord.Language_in_the_Home__c = 'Mandarin';
            RefRecord.Other_Language__c = 'Hindi';
            RefRecord.Primary_Contact_Is_Individual_Indicator__c = false;
            RefRecord.Is_Individual_Attending_School__c = 'Yes';
            RefRecord.Current_School__c = 'Test School';
            RefRecord.Who_does_the_youth_live_with__c = 'Family';
            RefRecord.Is_stable_housing_a_concern__c = '';
            RefRecord.Explain_housing_concern__c = 'Test Test';
            RefRecord.Special_limitations_hearing_sight_mob__c = 'Test';
            RefRecord.What_services_they_are_waiting_for__c = 'Test Services';
            RefRecord.DAA_or_other_cultural_or_spiritual_repre__c = 'Test';
            RefRecord.Referral_Notes__c = 'This is a test note.';
            RefRecord.ICY_Show_Banner__c = TRUE;
            RefRecord.ICY_Geographic_Area__c = 'Coast Mountains Team Hazelton';
            RefRecord.Case__c = objCase.Id;
            insert RefRecord;

            Intake__c intake = new Intake__c();
            intake.Referral__c = RefRecord.Id;
            insert intake;

            Case_Contact__c objCaseCon = new Case_Contact__c();
            objCaseCon.Intake__c = intake.id;
            insert objCaseCon;

            Case_Member__c objCaseM = new Case_Member__c();
            objCaseM.ICY_Case__c = objCase.id;
            objCaseM.ICY_Status__c = 'Active';
            objCaseM.ICY_Case_Contact__c = objCaseCon.id;
            insert objCaseM;

            List<YTS_Referral_Controller.TransitionPlan> listOfPlans = YTS_Referral_Controller.getCaseTransitionPlans(objCase.Id);
            YTS_Referral_Controller.getReferralId(intake.id);
            YTS_Haves_And_Needs__c testHaves = new YTS_Haves_And_Needs__c();
            testHaves.Contact_Organization__c = 'Test Organization';
            testHaves.Details__c = 'Test Have';
            testHaves.Have__c = 'Savings';
            testHaves.Transition_Plan__c = listOfPlans[0].transitionId;
            testHaves.End_Date__c = system.today()+2;
            testHaves.Have_Need_Other_Description__c = 'Test Description';
            insert testHaves;

            YTS_Haves_And_Needs__c testNeed = new YTS_Haves_And_Needs__c();
            testNeed.Contact_Organization__c = 'Test Organization';
            testNeed.Details__c = 'Test Have';
            testNeed.Need__c = 'Peers';
            testNeed.Transition_Plan__c = listOfPlans[0].transitionId;
            testNeed.End_Date__c = system.today()+2;
            testNeed.Have_Need_Other_Description__c = 'Test Description';
            insert testNeed;

            YTS_Goal_Steps__c goalStep = new YTS_Goal_Steps__c();
            goalStep.Action_Goal_Description__c = 'It is a long established fact that a reader will be distracted by the readable content of a page when looking at its layout.';
            goalStep.Current_Stage__c = 'In Progress';
            goalStep.Title__c = 'Open Social Media';
            goalStep.Transition_Needs__c = testHaves.Id;
            goalStep.Step_Completed_By__c = system.today()+5;
            goalStep.Assigned_Case_Team_Member__c = UserInfo.getUserId();
            goalStep.Who_Is_Supporting_this__c = 'Mommy';
            insert goalStep;
    }


    @isTest static void testCurrentUserType(){
        user u = [Select id from User where email = 'testLead@gov.bc.ca'];
        // system.runAs(u) {
            Test.startTest();
            ICY_IntegratedCarePlanCtrl.getCurrentUserType();
            Test.stopTest();
        // }
    }

    @isTest static void testCreateReferral(){
        user u = [Select id from User where email = 'testLead@gov.bc.ca'];
        // system.runAs(u) {
            Referral__c ref = [Select Id,Name From Referral__c Limit 1];
            Test.startTest();
            ICY_IntegratedCarePlanCtrl.createReferral(ref, ref.Id);
            Test.stopTest();
        // }

    }

    @isTest static void testReferralContacts(){
        user u = [Select id from User where email = 'testLead@gov.bc.ca'];
        // system.runAs(u) {
            Referral__c ref = [Select Id,Name From Referral__c Limit 1];

            test.startTest();
            ICY_IntegratedCarePlanCtrl.referralContacts(ref.Id);
            test.stopTest();
        // }
    }

    @isTest static void testGetReferralContact(){
        user u = [Select id from User where email = 'testLead@gov.bc.ca'];
        // system.runAs(u) {
            Case_Contact__c caseCon = [Select Id,Name From Case_Contact__c Limit 1];

            test.startTest();
            ICY_IntegratedCarePlanCtrl.getReferralContact(caseCon.Id);
            test.stopTest();
        // }
    }

    @isTest static void testUpsertCaseContact(){
        user u = [Select id from User where email = 'testLead@gov.bc.ca'];
        // system.runAs(u) {
            Case_Contact__c caseCon = [Select Id,Name From Case_Contact__c Limit 1];
            Referral__c ref = [Select Id,Name From Referral__c Limit 1];

            test.startTest();
            ICY_IntegratedCarePlanCtrl.upsertCaseContact(ref.Id,caseCon.Id,'TestFName','TestLName','9090909090','9191919191','9292929292','9393939393','test@gmail.com','Social Worker','Other','Phone');
            test.stopTest();
        // }
     }

    @isTest static void testGetCaseTransitionPlans(){
        user u = [Select id from User where email = 'testLead@gov.bc.ca'];
        // system.runAs(u) {
            Case caseRecord = [SELECT id from Case LIMIT 1];
            List<String> filter = new List<String>();
            filter.add('In Progress');
            filter.add('Completed');

            test.startTest();
            ICY_IntegratedCarePlanCtrl.getCaseAccountId(caseRecord.id);
            ICY_IntegratedCarePlanCtrl.CaseTeamWrapper objCT = new ICY_IntegratedCarePlanCtrl.CaseTeamWrapper();
            list<ICY_IntegratedCarePlanCtrl.TransitionPlan> transitionPlans =  ICY_IntegratedCarePlanCtrl.getCaseTransitionPlans(caseRecord.Id);
            ICY_IntegratedCarePlanCtrl.getTransitionHaves(transitionPlans[0].transitionId);
            ICY_IntegratedCarePlanCtrl.getTransitionNeeds(transitionPlans[0].transitionId);
            ICY_IntegratedCarePlanCtrl.getTransitionSteps(caseRecord.Id,filter);
            test.stopTest();
        // }
    }


    @isTest static void testGetServiceReviews(){
        user u = [Select id from User where email = 'testLead@gov.bc.ca'];
        // system.runAs(u) {
            Case_Contact__c caseCon = [Select Id,Name From Case_Contact__c Limit 1];
            Case caseRecord = [SELECT id from Case LIMIT 1];

            //RecordType rc = [select Id,Name from RecordType where sObjectType='Intake__c' And Name='Service Review' Limit 1];

            Intake__c intake = [Select Id,Name,RecordTypeId,Case__c From Intake__c Limit 1];
           // intake.RecordTypeId = rc.Id;
            intake.Case__c = caseRecord.Id;
            update intake;


            test.startTest();
            ICY_IntegratedCarePlanCtrl.getCaseTeam(caseRecord.Id);
            ICY_IntegratedCarePlanCtrl.getReferralId(intake.id);
            test.stopTest();
        // }
    }

    @isTest static void testGetMyGoalSteps(){
        user u = [Select id from User where email = 'testLead@gov.bc.ca'];
        YTS_Goal_Steps__c goalStep = [Select id from YTS_Goal_Steps__c LIMIT 1];
        YTS_Haves_And_Needs__c hNs = [Select id from YTS_Haves_And_Needs__c LIMIT 1];
        // system.runAs(u) {

        test.startTest();
            ICY_IntegratedCarePlanCtrl.getMyGoalSteps();
            ICY_IntegratedCarePlanCtrl.getHaveNeedRecord(hNs.id);
            ICY_IntegratedCarePlanCtrl.getStepRecord(goalStep.id);
        test.stopTest();
        // }
    }

}