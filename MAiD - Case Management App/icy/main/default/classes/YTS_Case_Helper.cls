/**
 *
 */
public with sharing class YTS_Case_Helper {
    //Static Boolean variable to run trigger only once per transaction.
    public static Boolean runOnlyOnce = true;
    //Method to create Transition Plan records
    public static void createCaseTransitionPlans(Set<Id> caseIds){
        runOnlyOnce = false;
        List<YTS_Transition_Plan__c> plansToInsert = new List<YTS_Transition_Plan__c>();
        String icyRecordType = 'ICY_Standard_Case';
        List<String> icyDomains = System.label.ICY_TransitionPlanDomainValues.split(':', 0);

        for(Case eachCase: [SELECT Id, RecordType.DeveloperName FROM CASE WHERE ID IN :caseIds]){
            for(String domain: icyDomains){
                plansToInsert.add(
                    new YTS_Transition_Plan__c(
                        Case__c = eachCase.Id,
                        Transition_Domain__c = domain
                    )
                );
            }
        }

        if(plansToInsert.size() > 0) Insert plansToInsert;
    }
}