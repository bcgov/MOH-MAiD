/**
 *
 */
trigger YTS_Case_Trigger on Case (before update, after insert, after update) {
  Boolean isTriggerActive = YTS_Trigger_Handler__mdt.getInstance('Case').active__c;
  List<Case> newCases= new List<Case>();
  //Create Transition Plans When a Case is Created
  if (Trigger.isAfter && Trigger.isInsert) {
      if (isTriggerActive) {
          List<Case> ICYCsNew = ICY_Utility.filterICYCases(Trigger.new);
          Set<Id> newCaseIds = new Set<Id>();
          for (Case c: ICYCsNew ){
              newCaseIds.add(c.Id);
              newCases.add(c);
          }
          if (!newCaseIds.isEmpty()) {
              YTS_Case_Helper.createCaseTransitionPlans(newCaseIds);
              ICY_CaseNotesHandler.afterInsert(newCases);
          }
      }
  }
  // InactiveStartDateUpdate trigger logic merged (before update)
  if (Trigger.isBefore && Trigger.isUpdate) {
      for (Case c : ICY_Utility.filterICYCases(Trigger.new)) {
          Case oldCase = Trigger.oldMap.get(c.Id);
          // If activity is false, clear start date; if true and start date is null, set to today
          if (c.Case_is_i__c == false) {
              c.Activity_Status_Start_Date__c = null;
          } else if (c.Activity_Status_Start_Date__c == null) {
              c.Activity_Status_Start_Date__c = System.today();
          }
          // If ICY_Waitlisted__c is unchecked (changed from true to false), update removal date to today
          if (oldCase.ICY_Waitlisted__c == true && c.ICY_Waitlisted__c == false) {
              c.ICY_Child_Youth_removed_from_waitlist__c = System.today();
          }

           // If ICY_Waitlisted__c is checked  (changed from false to true), update ICY_Child_Youth_added_to_waitlist__c to today
           if (oldCase.ICY_Waitlisted__c == false && c.ICY_Waitlisted__c == true) {
              c.ICY_Child_Youth_added_to_waitlist__c = System.today();
          }
      }
  }

  //Handle Close Case Removed as per ticket BCMOHAD-23038
 /* if(Trigger.isAfter && Trigger.isUpdate){
      List<Case> ICYCsNew =ICY_Utility.filterICYCases(trigger.new);
        if (!ICYCsNew.isEmpty()) {
          ICY_CaseTriggerHandler.sendClosedCaseEmailNotificationToLead(ICYCsNew, trigger.oldMap);
        } 
  }*/

}