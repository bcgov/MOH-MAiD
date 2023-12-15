public without sharing class ICY_CaseMemberTriggerHandler {

    @InvocableMethod(label='Send CaseMember Email Notification' description='Send CaseMember Email Notification to Lead')
    public static void sendCaseMemberEmailNotificationToLead(List<Case_Member__c> caseMemberlist){
        Id orgwideemailId = YTS_Utility.getICYOrgWideEmailAddressId();
        Case_Member__c objCaseMember = new Case_Member__c();
        String teamMemberUserId;
        String caseId;
        For(Case_Member__c objCM : caseMemberlist) {
            if(String.isNotBlank(objCM.ICY_Case__c)){
                caseId =objCM.ICY_Case__c;
                objCaseMember = objCM;
            }
            if(String.isNotBlank(objCM.ICY_User__c)){
                teamMemberUserId = objCM.ICY_User__c;
            }

        }
        if(String.isNotBlank(caseId)){
            Referral__c ref = [SELECT id,
                                       Referral_Notes__c,ICY_Accepted_Referral__c,
                                       ICY_Geographic_Area__c,
                                       Case__c,Case__r.casenumber, ICY_Date_of_Referral__c
                                   FROM Referral__c
                                   WHERE  Case__c = :caseId];

            if(ref!=null && String.isNotBlank(ref.ICY_Geographic_Area__c)){
                String queueName='%'+ref.ICY_Geographic_Area__c;
                List<String> toAddressess = new List<String>();
                Set<Id> groupOrQueuId = new Set<Id>();
                Set<Id> roleId = new Set<Id>();
                Set<Id> userid = new Set<Id>();
                For(GroupMember gm: [SELECT UserOrGroupId FROM GroupMember WHERE Group.Type = 'Queue' AND Group.Name LIKE :queueName]){
                   if((String.valueOf(gm.UserOrGroupId)).startsWithIgnoreCase('00G')){
                        groupOrQueuId.add(gm.UserOrGroupId);
                    }else{
                        userid.add(gm.UserOrGroupId);
                    }
                }
                if(!groupOrQueuId.isEmpty()){
                    For(Group gm: [SELECT RelatedId,Type,DeveloperName FROM group WHERE Id IN:groupOrQueuId AND Type = 'Role']){
                        if(gm.Type=='Role'){
                            roleId.add(gm.RelatedId);
                        }
                    }
                }
                if(!roleId.isEmpty() || !userid.isEmpty()){
                    For(User u: [SELECT Id,email FROM User WHERE (UserRoleId =: roleId OR ID IN:userid) AND isActive = true]){
                        toAddressess.add(u.email);
                    }
                }
                if(!toAddressess.isEmpty()){
                    Messaging.SingleEmailMessage semail = new Messaging.SingleEmailMessage();
                    semail.setToAddresses(toAddressess);
                    if(orgwideEmailId != null) semail.setOrgWideEmailAddressId(orgwideEmailId);
                    semail.setSubject('New CaseMember#'+objCaseMember.Name+' has been Added');
                    String htmlBody= 'Hi,</br>'+userInfo.getName()+' has been assigned to case <a href="'+URL.getSalesforceBaseUrl().toExternalForm()+'/'+objCaseMember.ICY_Case__c+'">'+ref.Case__r.casenumber+'</a>. Please follow this link for details' ;
                    semail.setHtmlBody(htmlBody);
                    Messaging.sendEmail(new Messaging.SingleEmailMessage[] {semail});
                }
                if(String.isNotBlank(teamMemberUserId)){
                    String emailId = [SELECT Email FROM USER WHERE ID=:teamMemberUserId].Email;
                    Messaging.SingleEmailMessage semail = new Messaging.SingleEmailMessage();
                    semail.setToAddresses(new List<String>{emailId});
                    // if(orgwideEmailId != null) semail.setOrgWideEmailAddressId(orgwideEmailId);
                    semail.setSubject('Case Assignment Notification');
                    String htmlBody = 'Hi,<br/> You have been assigned to case <a href="'+URL.getSalesforceBaseUrl().toExternalForm()+'/'+objCaseMember.ICY_Case__c+'">'+ref.Case__r.casenumber+'</a>.'+'Please follow this link for details';
                    semail.setHtmlBody(htmlBody);
                    Messaging.sendEmail(new Messaging.SingleEmailMessage[] {semail});
                }
            }
        }
    }

    public static Map<Id,Referral__c> getReferralDetails(Set<Id> caseIds){
        Map<Id,Referral__c> caseReferralMap = new Map<Id,Referral__c>();
        List<Referral__c> referalList =[SELECT id,
                                        		Referral_Notes__c,ICY_Accepted_Referral__c,
                                        		ICY_Geographic_Area__c,
                                        		Case__c,ICY_Date_of_Referral__c
                                        	FROM Referral__c
                                        		WHERE  Case__c = :caseIds];

        for(Referral__c objRef : referalList){
            caseReferralMap.put(objRef.Case__c,objRef);
        }
        return caseReferralMap;
    }
}