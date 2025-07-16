public class ICY_ReopenCaseCtrl {
	@AuraEnabled(cacheable=true)
    public static String checkClosedDate(String caseId) {
        if(string.isNotBlank(caseId)) {
            Case objCase = [SELECT Id, ClosedDate FROM Case Where ID=: caseId];
            if(objCase.ClosedDate != null){
                // Always return Yes if closeddate is not null                
                return 'Yes';
            }
        }
      return 'No';
    }

    @AuraEnabled(cacheable=true)
    public static Referral__c getReferralDetails(String caseId){
        Referral__c ref = new Referral__c();
        if(string.isNotBlank(caseId)) {
            ref = [Select id, Referral_Notes__c,ICY_Accepted_Referral__c,ICY_Geographic_Area__c,
                                Case__c,ICY_Date_of_Referral__c from
                                Referral__c WHERE  Case__c=:caseId LIMIT 1];
        }
        return ref;
    }

    @AuraEnabled(cacheable=true)
    public static void sendEmailNotificationToLocationManager(String caseId){
        if(String.isNotBlank(caseId)){
            Referral__c ref = getReferralDetails(caseId);
            Id orgwideemailId = YTS_Utility.getICYOrgWideEmailAddressId();
            Case c= [Select id, caseNumber, subject, ownerid, description from Case where Id=:caseId];
            if(ref!=null && String.isNotBlank(ref.ICY_Geographic_Area__c)){
                String queueName='%'+ref.ICY_Geographic_Area__c;
                List<String> toAddressess = new List<String>();
                system.debug('queueName'+queueName);
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
                system.debug('groupdIds'+groupOrQueuId);
                system.debug('userid'+userid);
                if(!groupOrQueuId.isEmpty()){
                    For(Group gm: [SELECT RelatedId,Type,DeveloperName FROM group WHERE Id IN:groupOrQueuId AND Type = 'Role']){
                        if(gm.Type=='Role'){
                            roleId.add(gm.RelatedId);
                        }
                    }
                }
                system.debug('roleId'+roleId);
                if(!roleId.isEmpty() || !userid.isEmpty()){
                    For(User u: [SELECT Id,email FROM User WHERE (UserRoleId =: roleId OR ID IN:userid) AND isActive = true]){
                        if (u.id != UserInfo.getUserId()){
                            toAddressess.add(u.email);
                           }
                    }
                }
                system.debug('toAddressess'+toAddressess);
                String Recordlink = URL.getSalesforceBaseUrl().toExternalForm()+'/'+c.id;
                if(!toAddressess.isEmpty()){
                    Messaging.SingleEmailMessage semail = new Messaging.SingleEmailMessage();
                    semail.setToAddresses(toAddressess);
                    semail.setSubject('The Case#'+c.caseNumber+' has been reopened');
                    String htmlBody= 'Hi,</br>'+'Case <a href="'+Recordlink+'">'+c.CaseNumber+'</a> has been re-opened';
                    semail.setHtmlBody(htmlBody);
                    if(orgwideEmailId != null) semail.setOrgWideEmailAddressId(orgwideEmailId);
                    Messaging.sendEmail(new Messaging.SingleEmailMessage[] {semail});
                }
            }
        }
    }

}