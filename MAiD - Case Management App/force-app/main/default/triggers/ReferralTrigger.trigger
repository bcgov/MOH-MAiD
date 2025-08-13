trigger ReferralTrigger on Referral__c (after insert, after update) {
    ReferralTriggerHandler.handleAfterInsertOrUpdate(Trigger.new);
}