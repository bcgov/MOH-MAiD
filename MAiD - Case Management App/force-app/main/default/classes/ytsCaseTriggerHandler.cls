public with sharing class ytsCaseTriggerHandler {

//*****Create Contribition record update/create of Plan's Have or Need ******************************************************************************//
	
        public static void NewContributionforPlanHaveNeed(List<YTS_Haves_And_Needs__c> planHaveNeeds, string actionType){

            Set<Id> planHaveNeedIDs =  new Set<Id>();
            for(YTS_Haves_And_Needs__c planHaveNeed: planHaveNeeds){
                planHaveNeedIDs.add(planHaveNeed.Id);
            }

            List<Contribution__c> newContributionList = new List<Contribution__c>();

            for(YTS_Haves_And_Needs__c ytsPlanHaveNeed: [select Id, Have__c, Need__c, Transition_Plan__c, Transition_Plan__r.Transition_Domain__c, Transition_Plan__r.Case__c, 
                                                                lastmodifieddate  from YTS_Haves_And_Needs__c where Id IN:planHaveNeedIDs ORDER BY lastmodifieddate  DESC ]){

                Contribution__c newContribution  = new Contribution__c();
                newContribution.Action__c = actionType;  //actionType = create or update coming from trigger
                newContribution.Case__c = ytsPlanHaveNeed.Transition_Plan__r.Case__c;
                newContribution.Transition_Plan_Domain__c = ytsPlanHaveNeed.Transition_Plan__r.Transition_Domain__c;
                //newContribution.Transition_Plan__c = ytsPlanHaveNeed.Transition_Plan__c;
                if(ytsPlanHaveNeed.Have__c != null){
                    newContribution.Contribution_Type__c = 'Have';
                    newContribution.Have_Need__c = ytsPlanHaveNeed.Have__c;
                }else {
                    newContribution.Contribution_Type__c = 'Need';
                    newContribution.Have_Need__c = ytsPlanHaveNeed.Need__c;	
                }

                newContributionList.add(newContribution);
            }

            insert newContributionList;	
        }
}