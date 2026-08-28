trigger ReferralTrigger on Referral__c (after insert, after update) {

   if(Trigger.isUpdate){
        ReferralTriggerHandler.handleGeographicAreaChange(
            Trigger.new,
            Trigger.oldMap
        );
    }

    ReferralTriggerHandler.handleAfterInsertOrUpdate(Trigger.new);
}