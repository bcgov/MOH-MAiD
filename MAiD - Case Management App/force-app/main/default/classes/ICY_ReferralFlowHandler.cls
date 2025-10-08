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
                Set<Id> useridInGroup = new Set<Id>();
                Set<Id> userid = new Set<Id>();
                For(GroupMember gm: [SELECT UserOrGroupId FROM GroupMember WHERE Group.Type = 'Queue' AND Group.Name LIKE :queueName]){
                   if((String.valueOf(gm.UserOrGroupId)).startsWithIgnoreCase('00G')){
                        groupOrQueuId.add(gm.UserOrGroupId);
                    }else{
                        userid.add(gm.UserOrGroupId);
                    }
                }
                if(!groupOrQueuId.isEmpty()){
                    For (GroupMember gm : [SELECT UserOrGroupId FROM GroupMember WHERE GroupId IN:groupOrQueuId AND UserOrGroupId IN (SELECT Id FROM User)]) {
                         useridInGroup.add(gm.UserOrGroupId);
                   }
                }
                if(!useridInGroup.isEmpty()){
                    For(User usr: [SELECT id FROM user WHERE Id IN:useridInGroup AND UserRole.DeveloperName  like '%Program_Leader%']){
                        userid.add(usr.id);
                    }
                }
                
                if(!userid.isEmpty()){
                    For(User u: [SELECT Id,Name, email FROM User WHERE ID IN:userid AND isActive = true]){
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