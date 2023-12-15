trigger Case_TransitionPlan on YTS_Haves_And_Needs__c ( after insert, after update) {

    if(Trigger.isAfter){

        if(Trigger.isInsert){
            ytsCaseTriggerHandler.NewContributionforPlanHaveNeed(Trigger.new, 'Create');  
        }else if (Trigger.isUpdate) {
            ytsCaseTriggerHandler.NewContributionforPlanHaveNeed(Trigger.new, 'Update');
        } else {
                System.debug('do nothing');   
        }
    }
}