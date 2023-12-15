/**
 *
 */
trigger YTS_Case_Trigger on Case (after insert, after update) {
  Boolean isTriggerActive = YTS_Trigger_Handler__mdt.getInstance('Case').active__c;
  //Create Transition Plans When a Case is Created
  if(Trigger.isAfter && Trigger.isInsert){
      if(isTriggerActive){
          List<Case> ICYCsNew =ICY_Utility.filterICYCases(trigger.new);
          Set<Id> newCaseIds = new Set<Id>();
          for (Case c: ICYCsNew ){
              newCaseIds.add(c.Id);
          }
          if (!newCaseIds.isEmpty()) {
            YTS_Case_Helper.createCaseTransitionPlans(newCaseIds);
          }
      }
  }
  //Handle Close Case
  if(Trigger.isAfter && Trigger.isUpdate){
      List<Case> ICYCsNew =ICY_Utility.filterICYCases(trigger.new);
        if (!ICYCsNew.isEmpty()) {
          ICY_CaseTriggerHandler.sendClosedCaseEmailNotificationToLead(ICYCsNew, trigger.oldMap);
        }
  }

}