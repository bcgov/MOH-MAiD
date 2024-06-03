public class ICY_ReferralFlowHandler {
	@InvocableMethod(label='Send Referral created Email Notification' description='Send Referral created Email Notification')
    public static void sendClosedIntakeEmailNotificationToLead(List<Referral__c> referralList){
        Referral__c  objReferral = new Referral__c ();
        For(Referral__c  objRef : referralList) {
            objReferral = objRef;
        }
       
            if(String.isNotBlank(objReferral.ICY_Geographic_Area__c)){  
                String queueName = '%'+objReferral.ICY_Geographic_Area__c.replace('-', ' ')+'%';
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
                    For(Group gm: [SELECT RelatedId,Type,DeveloperName FROM group WHERE Id IN:groupOrQueuId AND Type = 'Role'and DeveloperName  like '%Program_Leader%']){
                        roleId.add(gm.RelatedId);
                    }
                }
                
                if(!roleId.isEmpty() || !userid.isEmpty()){
                    For(User u: [SELECT Id,Name, email FROM User WHERE (UserRoleId =: roleId OR ID IN:userid ) AND isActive = true]){
                            toAddressess.add(u.email);
                        }
                    }
               
                Id orgwideemailId = YTS_Utility.getICYOrgWideEmailAddressId();
                if(!toAddressess.isEmpty()){
                    Messaging.SingleEmailMessage semail = new Messaging.SingleEmailMessage();
                    semail.setToAddresses(toAddressess);
                    semail.setSubject('New Referral has been created');
                   // String htmlBody= 'Hi,</br>'+'The Intake record <a href="'+Recordlink+'">'+objIntake.Name+'</a> has been Closed by '+whoClosed.Name;
                    String htmlBody = 'Hello,<br/><br/>' + '<a href="'+URL.getSalesforceBaseUrl().toExternalForm()+'/'+objReferral.id+'">'+objReferral.Name+'</a> has been created. Please follow the link for more details.Thank you.';

                    
                    semail.setHtmlBody(htmlBody);
                    if(orgwideEmailId != null) semail.setOrgWideEmailAddressId(orgwideEmailId);
                    Messaging.sendEmail(new Messaging.SingleEmailMessage[] {semail});
                }
            }
        }
    }