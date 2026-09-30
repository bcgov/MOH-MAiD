global class ClearDraftReferralScheduler implements Schedulable {
   global void execute(SchedulableContext SC) {
       deleteReferrals();  
   }
   public void deleteReferrals(){
       List<Referral__c> draftRefList = [select id from Referral__c where Status__c='Draft'];
       delete draftRefList;
   }
}