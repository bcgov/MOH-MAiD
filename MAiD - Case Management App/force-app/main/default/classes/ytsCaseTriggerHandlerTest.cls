@isTest
public with sharing class ytsCaseTriggerHandlerTest {

    @TestSetup
    static void makeData(){

        Case cs = new Case();
        cs.Subject = 'Test1';
        cs.Status = 'Open';
        cs.Location__c = 'Peace North';
        cs.Region__c = 'Northern Region';
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