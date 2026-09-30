@isTest
public class ICY_CaseMemberTriggerHandlerTest {
    
    @testSetup static void testSetup(){
        ICY_ReferralFeatureUtilityTest.setup();
      }
    
    @isTest static void testSendCaseMemberEmailNotificationToLead(){
        
        Case caseRecord = [SELECT id from Case LIMIT 1];
        Set<Id> caseIdSet = new Set<Id>();
        caseIdSet.add(caseRecord.Id);
        Referral__c ref = [Select Id,Name From Referral__c Limit 1];
        Case_Member__c objCM = new Case_Member__c();
            objCM.Referral__c = ref.id;
            objCM.ICY_Case__c = caseRecord.id;
            //objCM.ICY_User__c = userinfo.getUserId();
            objCM.ICY_Status__c = 'Active';
            objCM.ICY_Category_Assignment__c = 'Consulting';
            insert objCM;
        List<Case_Member__c> cmList = new List<Case_Member__c>();
        cmList.add(objCM);
    
        Test.startTest();
        ICY_CaseMemberTriggerHandler.sendCaseMemberEmailNotificationToLead(cmList);
        ICY_CaseMemberTriggerHandler.getReferralDetails(caseIdSet);
        Test.stopTest();
    }

}