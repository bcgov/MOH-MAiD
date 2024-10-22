trigger Case_Member on Case_Member__c (after insert, after update,before delete ) {
    List<Case_Member__c> lstCaseMember = new List<Case_Member__c>();
    if (Trigger.isAfter) {
        for(Case_Member__c cm:Trigger.New) 
        {	 
            lstCaseMember.add(cm); 
        }
        if ((Trigger.isInsert ) || (Trigger.isUpdate)){
            ICY_CaseMember_Controller.updateReferralTeamMemberIds(lstCaseMember,false);
        }
       
    }
    if (Trigger.isBefore) {
        if (Trigger.isDelete){
            for(Case_Member__c cm:Trigger.old) 
            {	 
                lstCaseMember.add(cm); 
            }
            ICY_CaseMember_Controller.updateReferralTeamMemberIds(lstCaseMember,true);
        }
    }
}