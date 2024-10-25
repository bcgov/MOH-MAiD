trigger Case_Member on Case_Member__c (after insert, after update,after delete ) {
    List<Case_Member__c> lstCaseMemberTeamMemberIds = new List<Case_Member__c>();

    if (Trigger.isAfter) {
        if ((Trigger.isInsert) || (Trigger.isUpdate)){
            for(Case_Member__c cm:Trigger.New) 
            {   
                lstCaseMemberTeamMemberIds.add(cm); 
            }

            if ((Trigger.isInsert ) || (Trigger.isUpdate)){
                ICY_CaseMember_Controller.updateReferralTeamMemberIds(lstCaseMemberTeamMemberIds,false);
            }
        }
       
        if (Trigger.isDelete){
            for(Case_Member__c cm:Trigger.old) 
            {   
                lstCaseMemberTeamMemberIds.add(cm); 
            }
            ICY_CaseMember_Controller.updateReferralTeamMemberIds(lstCaseMemberTeamMemberIds,true);
        }
    }
}