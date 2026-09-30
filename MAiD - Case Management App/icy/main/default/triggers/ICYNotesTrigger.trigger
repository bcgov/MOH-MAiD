trigger ICYNotesTrigger on ICY_Notes__c (after insert,after update) {
    if(trigger.isInsert){
        ICYNotesTriggerHandler.doInsert(trigger.new);
    }
    List<Case> lstOfCasesToUpdate = new List<Case>();
    for(ICY_Notes__c obj:trigger.new){
        if(obj.Case__c !=null){
            Case caseObj = new Case();
            caseObj.Id = obj.Case__c;
            caseObj.Last_Active_Date__c = Date.today();
            lstOfCasesToUpdate.add(caseObj);
        }
    }
    try{
        if(!lstOfCasesToUpdate.isEmpty()){
            update lstOfCasesToUpdate;
        }
    }catch(Exception ex){}
}