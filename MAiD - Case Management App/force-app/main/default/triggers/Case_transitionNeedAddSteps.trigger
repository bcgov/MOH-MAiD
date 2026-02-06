trigger Case_transitionNeedAddSteps on YTS_Goal_Steps__c (after insert, after update) {

    if (Trigger.isAfter) {
        if(Trigger.isInsert || Trigger.isUpdate){

            Set<Id> transitionHavesNeedsIds = new Set<Id>();
            for(YTS_Goal_Steps__c stepRecord: Trigger.new){
                transitionHavesNeedsIds.add(stepRecord.Transition_Needs__c);
            }
            List<YTS_Haves_And_Needs__c> relatedHavesNeeds = new List<YTS_Haves_And_Needs__c>();
            relatedHavesNeeds = [select Id, Have__c, Need__c, Transition_Plan__c, Transition_Plan__r.Transition_Domain__c, Transition_Plan__r.Case__c, 
                            lastmodifieddate  from YTS_Haves_And_Needs__c where Id IN:transitionHavesNeedsIds ORDER BY lastmodifieddate  DESC ];
            
            ytsCaseTriggerHandler.NewContributionforPlanHaveNeed(relatedHavesNeeds, 'Update');
        }
    }

}