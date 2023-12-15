public class ICY_IntakeFlowHandler {
	@InvocableMethod(label='Send Closed Intake Email Notification' description='Send Closed intake Email Notification to Lead')
    public static void sendClosedIntakeEmailNotificationToLead(List<Intake__c> intakeList){
        Intake__c  objIntake = new Intake__c ();
        For(Intake__c  objinTk : intakeList) {
            objIntake = objinTk;
        }
        if(String.isNotBlank(objIntake.Referral__c)){
            Referral__c ref = [SELECT id,
                                       ICY_Geographic_Area__c
                                   FROM Referral__c
                                   WHERE  Id = :objIntake.Referral__c];

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
                user whoClosed;
                if(!roleId.isEmpty() || !userid.isEmpty()){
                    For(User u: [SELECT Id,Name, email FROM User WHERE (UserRoleId =: roleId OR ID IN:userid OR ID =:objIntake.ICY_Who_Is_Doing__c) AND isActive = true]){
                        if(String.isBlank(objIntake.ICY_Who_Is_Doing__c) ||
                            u.Id != objIntake.ICY_Who_Is_Doing__c){
                            toAddressess.add(u.email);
                        }
                        if(U.id == objIntake.ICY_Who_Is_Doing__c){
                            whoClosed = U;
                        }
                    }
                }
                String Recordlink = URL.getSalesforceBaseUrl().toExternalForm()+'/'+objIntake.id;
                Id orgwideemailId = YTS_Utility.getICYOrgWideEmailAddressId();
                if(!toAddressess.isEmpty()){
                    Messaging.SingleEmailMessage semail = new Messaging.SingleEmailMessage();
                    semail.setToAddresses(toAddressess);
                    semail.setSubject('Intake#'+objIntake.Name+' has been Closed');
                    String htmlBody= 'Hi,</br>'+'The Intake record <a href="'+Recordlink+'">'+objIntake.Name+'</a> has been Closed by '+whoClosed.Name;
                    semail.setHtmlBody(htmlBody);
                    if(orgwideEmailId != null) semail.setOrgWideEmailAddressId(orgwideEmailId);
                    Messaging.sendEmail(new Messaging.SingleEmailMessage[] {semail});
                }
            }
        }
    }
}