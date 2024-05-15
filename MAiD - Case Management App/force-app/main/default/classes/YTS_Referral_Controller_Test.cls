@isTest
public with sharing class YTS_Referral_Controller_Test {

    @testSetup static void setup() {

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
        insert RefRecord;

        String testString = YTS_Referral_Controller.createReferral(RefRecord,RefRecord.Id);
        System.debug(testString);

        //Create Content Version
        ContentVersion cv = new ContentVersion();
        cv.VersionData = EncodingUtil.base64Decode('base64');
        cv.Title = 'fileName';
        cv.PathOnClient = 'fileName';
        Insert cv;

        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion Where Id=:cv.Id].ContentDocumentId;
        cdl.shareType = 'I';
        cdl.visibility = 'AllUsers';
        cdl.LinkedEntityId = RefRecord.Id;
        Insert cdl;

        Case cas = new case();
        cas.Status = 'New';
        cas.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('ICY_Standard_Case').getRecordTypeId();
        cas.Referral__c=RefRecord.id;
        insert cas;

        RefRecord.Case__c= cas.Id;
        upsert(RefRecord);

        Intake__c intke= new Intake__c();
        insert intke;

        String caseContactId = YTS_Referral_Controller.upsertCaseContact(RefRecord.Id,'','firstName','lastName','8887779999','7776667777','','1112221111','test@test.com','Parent','','Phone');
        Case_Contact__c caseContact = YTS_Referral_Controller.getReferralContact(caseContactId);
        List<Case_Contact__c> listOfReferralContacts = YTS_Referral_Controller.referralContacts(RefRecord.Id);

        String caseContactString = YTS_Referral_Controller.getCaseContactRecordTypeId();
    }

    @isTest static void test_InactiveStartDateUpdate() {
        Case caseRecord = [SELECT id from Case LIMIT 1];
        caseRecord.Case_is_i__c = true;
        caseRecord.Activity_Status_Start_Date__c=null;
        update caseRecord;
    }

    @isTest static void test_YTS_Case_Helper() {
        Case caseRecord = [SELECT id from Case LIMIT 1];
        caseRecord.Status = 'Closed';
        update caseRecord;
    }

    @isTest static void test_YTS_Notes_Documents_Controller(){
        Case caseRecord = [SELECT id from Case LIMIT 1];
        String IntakeId = [SELECT id,Referral__c from Intake__c LIMIT 1].Id;
        Referral__c RefRecord = [SELECT id from Referral__c LIMIT 1];
        String caseContactId = [SELECT id from Case_Contact__c LIMIT 1].Id;

        YTS_Notes_Documents_Controller ytsNotesController = new YTS_Notes_Documents_Controller();

        //Create Content Version
        ContentVersion cv = new ContentVersion();
        cv.VersionData = EncodingUtil.base64Decode('base64');
        cv.Title = 'fileName';
        cv.PathOnClient = 'fileName';
        Insert cv;

        YTS_Notes_Documents_Controller.ParentwithContact relatedCaseContacts = YTS_Notes_Documents_Controller.getRelatedContacts(caseRecord.Id);
        YTS_Notes_Documents_Controller.ParentwithContact relatedIntakeContacts = YTS_Notes_Documents_Controller.getRelatedContacts(IntakeId);
        YTS_Notes_Documents_Controller.ParentwithContact relatedRefContacts = YTS_Notes_Documents_Controller.getRelatedContacts(RefRecord.Id);
        List<YTS_Notes_Documents_Controller.RelatedIntake> relatedIntakes =  YTS_Notes_Documents_Controller.getRelatedIntakes(RefRecord.Id);

        String UserName = YTS_Notes_Documents_Controller.getUserProfileName();

        YTS_Referral_Controller.deleteCaseContactRecord(caseContactId);
    }

    @isTest static void test_YTS_Referral_Controller(){

        Case caseRecord = [SELECT id from Case LIMIT 1];
        list<String> GoalStepStatuses = new list<String>();
        GoalStepStatuses.add('In Progress');
        GoalStepStatuses.add('Completed');
        YTS_Referral_Controller refController = new YTS_Referral_Controller();
        list<YTS_Referral_Controller.TransitionPlan> listOfPlans = YTS_Referral_Controller.getCaseTransitionPlans(caseRecord.Id);
        system.debug(listOfPlans);
        List<YTS_Referral_Controller.CaseTeamWrapper> getCaseTeam = YTS_Referral_Controller.getCaseTeam(caseRecord.Id);

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
        goalStep.Transition_Needs__c = testNeed.Id;
        goalStep.Step_Completed_By__c = system.today()+5;
        goalStep.Assigned_Case_Team_Member__c = UserInfo.getUserId();
        goalStep.Who_Is_Supporting_this__c = 'Mommy';
        insert goalStep;

        system.debug(listOfPlans[0].transitionId);
        list<YTS_Referral_Controller.TransitionGoalSteps> listOfGoalSteps = YTS_Referral_Controller.getTransitionSteps(caseRecord.Id,GoalStepStatuses);
        list<YTS_Referral_Controller.PlanHaves> listOfTransitionHaves = YTS_Referral_Controller.getTransitionHaves(listOfPlans[0].transitionId);
        list<YTS_Referral_Controller.PlanNeeds> listOfTransitionNeeds = YTS_Referral_Controller.getTransitionNeeds(listOfPlans[0].transitionId);

        YTS_Haves_And_Needs__c testHaveNeed = YTS_Referral_Controller.getHaveNeedRecord(testNeed.Id);
        list<YTS_Referral_Controller.TransitionGoalSteps> getGoalSteps = YTS_Referral_Controller.getMyGoalSteps();
        YTS_Transition_Plan__c transitionPlan = [SELECT Id from YTS_Transition_Plan__c LIMIT 1];
      	Test.startTest();
        Id transitionId = listOfPlans[0].transitionId;
        System.debug(transitionId);
        String transitionIds;
        for(YTS_Transition_Plan__c tp: [select id from YTS_Transition_Plan__c Where case__C = :caseRecord.Id]){
            if(String.isBlank(transitionIds)) transitionIds = tp.Id;
            else transitionIds += ',' + tp.Id;
        }
        System.debug('$$ Transition Plans: '+transitionIds);

        PageReference pageRef = Page.YTS_Print_Transition_Plans;
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('c__transitionIds', transitionIds);
        ApexPages.currentPage().getParameters().put('c__caseId', caseRecord.Id);
        ApexPages.currentPage().getParameters().put('c__planType', '_blank');
        YTS_Print_Transition_Plan_Controller printControl = new YTS_Print_Transition_Plan_Controller();

        ApexPages.currentPage().getParameters().put('c__transitionIds', goalStep.Id);
        YTS_Print_Transition_Plan_Controller printControl2 = new YTS_Print_Transition_Plan_Controller();
		Test.stopTest();
    }

    @isTest static void test_YTS_Utility(){
        Map<string,string> picklistValues = YTS_Utility.getPicklistValues('Referral__c','Individual_Gender__c');
        System.debug(picklistValues);
        System.debug(YTS_Utility.dateFormat_eeeeMMMdyyyy(system.today()));
        System.debug(YTS_Utility.dateFormat_eeeeMMMdyyyy(system.now()));
        System.debug(YTS_Utility.dateFormat_MMMdyyyy(system.today()));
        System.debug(YTS_Utility.dateFormat_yyyy_mm_dd(system.today()));
    }


}