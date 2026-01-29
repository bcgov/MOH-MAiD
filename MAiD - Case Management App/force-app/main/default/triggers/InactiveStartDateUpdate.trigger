trigger InactiveStartDateUpdate on Case (before update) {
  for (Case c: (ICY_Utility.filterICYCases(trigger.new)))
  {      Case oldCase = Trigger.oldMap.get(c.ID);
          if(c.Case_is_i__c == FALSE)
          {
              c.Activity_Status_Start_Date__c = null;
          }
          else if(c.Activity_Status_Start_Date__c == null)
          {
              c.Activity_Status_Start_Date__c = System.Today();
          }
   }
}