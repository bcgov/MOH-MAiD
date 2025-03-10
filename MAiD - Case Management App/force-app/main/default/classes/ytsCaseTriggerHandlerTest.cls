@isTest
public with sharing class ytsCaseTriggerHandlerTest {

    @TestSetup
    static void makeData(){

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

        Case cs = new Case();
        cs.Subject = 'Test1';
        cs.Status = 'Open';
        cs.Location__c = 'Peace North';
        cs.Region__c = 'Northern Region';
        cs.referral__c= RefRecord.Id;
        cs.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('ICY_Standard_Case').getRecordTypeId();

        insert cs;

        YTS_Transition_Plan__c plan = new YTS_Transition_Plan__c();
        plan.Case__c = cs.Id;
        plan.Transition_Domain__c = 'Team';

        insert plan;

        YTS_Haves_And_Needs__c ytsHaveNeed = new YTS_Haves_And_Needs__c();
        ytsHaveNeed.Transition_Plan__c = plan.Id;
        ytsHaveNeed.Need__c = 'Network';

        insert ytsHaveNeed;

        YTS_Goal_Steps__c needPlanStep = new YTS_Goal_Steps__c();
        needPlanStep.Transition_Needs__c = ytsHaveNeed.Id;
        needPlanStep.Current_Stage__c = 'In Progress';
        needPlanStep.Step_Completed_By__c = Date.valueOf('2023-05-02');

        insert needPlanStep;

    }


    @isTest
    static void testPlanInsertTrigger(){
            //for Have - create

            YTS_Transition_Plan__c plan1 = [select Id, Transition_Domain__c from YTS_Transition_Plan__c where Transition_Domain__c = 'Team'];

            YTS_Haves_And_Needs__c ytsHaveNeed1 = new YTS_Haves_And_Needs__c();
            ytsHaveNeed1.Transition_Plan__c = plan1.Id;
            ytsHaveNeed1.Have__c = 'Friend';

       try {
            insert ytsHaveNeed1;

       } catch (Exception e) {
            System.debug(e);
       }

       List<Contribution__c> conRecord = [select id, Action__c from Contribution__c];

       system.assert(conRecord.size()>0, 'Contribution Record not found for insert trigger');

    }

    @isTest
    static void testPlanUpdateTrigger(){
        //for Need - update

        YTS_Haves_And_Needs__c ytsHaveNeed2 = [select id, Need__c from YTS_Haves_And_Needs__c where Need__c = 'Network' ];
        ytsHaveNeed2.Need__c = 'Physician';

        try {
            update ytsHaveNeed2;

       } catch (Exception e) {
            System.debug(e);
       }

       List<Contribution__c> conRecord = [select id, Action__c from Contribution__c];

       system.assert(conRecord.size()>0, 'Contribution Record not found for update trigger');

    }


    @isTest
    static void testNeedStepsUpdateTrigger(){
        //for need steps

        YTS_Goal_Steps__c needPlanStep1 = [select Id, Current_Stage__c from YTS_Goal_Steps__c where Current_Stage__c = 'In Progress'];
        needPlanStep1.Current_Stage__c= 'Completed';

        try {
            update needPlanStep1;

       } catch (Exception e) {
            System.debug(e);
       }

       List<Contribution__c> conRecord = [select id, Action__c from Contribution__c];

       system.assert(conRecord.size()>0, 'Contribution Record not found for update NeedAddStep trigger');


    }
}