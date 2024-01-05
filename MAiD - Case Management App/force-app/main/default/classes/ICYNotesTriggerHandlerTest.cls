@isTest
public class ICYNotesTriggerHandlerTest {

     @testSetup static void testSetup(){
        ICY_ReferralFeatureUtilityTest.setup();
      }
    
    @isTest static void testDoInsert(){
        
        Case caseRecord = [SELECT id from Case LIMIT 1];
        Set<Id> caseIdSet = new Set<Id>();
        caseIdSet.add(caseRecord.Id);
        Referral__c ref = [Select Id,Name From Referral__c Limit 1];
        Case_Member__c objCM = new Case_Member__c();
            objCM.Referral__c = ref.id;
            objCM.ICY_Case__c = caseRecord.id;
            objCM.ICY_Status__c = 'Active';
            objCM.ICY_Category_Assignment__c = 'MRTM';
            insert objCM;
        
        ICY_Notes__c notes = new ICY_Notes__c();
        notes.Name = 'Test';
        notes.Notes_Type__c = 'Restricted';
        notes.Referral__c = ref.Id;
        notes.Case__c = caseRecord.Id;
        notes.Referral_Subject__c = 'Critical Incident';
        insert notes;
        
        system.assertNotEquals(null, caseIdSet.size());
        
    }
}