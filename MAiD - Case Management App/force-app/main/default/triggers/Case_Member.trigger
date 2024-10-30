trigger Case_Member on Case_Member__c (after insert, after update,after delete ) {
    List<Case_Member__c> lstCaseMemberTeamSize = new List<Case_Member__c>();

    if (Trigger.isAfter) {
        if ((Trigger.isInsert) || (Trigger.isUpdate)){
            for(Case_Member__c cm:Trigger.New) 
            {    
                if (cm.ICY_Case__c != Null){
                    lstCaseMemberTeamSize.add(cm);
                }
            }

            if ((Trigger.isInsert ) || (Trigger.isUpdate)){
              ICY_CaseMember_Controller.updateCaseTeamSize(lstCaseMemberTeamSize);
            }
        }
       
        if (Trigger.isDelete){
            for(Case_Member__c cm:Trigger.old) 
            {    
                if (cm.ICY_Case__c != Null){
                    lstCaseMemberTeamSize.add(cm);
                }
            }
           ICY_CaseMember_Controller.updateCaseTeamSize(lstCaseMemberTeamSize);
        }
    }
}