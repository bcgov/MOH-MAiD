public with sharing class ICYNotesTriggerHandler{
    public static void doInsert(List<ICY_Notes__c> triggerNew){
        set<Id> setOfCaseIds = new set<Id>();
        for(ICY_Notes__c obj:triggerNew){
            if(obj.Referral_Subject__c == 'Critical Incident' && obj.Case__c!=null){
                setOfCaseIds.add(obj.Case__c);
            }
        } 
        
        
       map<Id,List<String>> mapOfCaseIdUserEmail = new map<Id,List<String>>();
       
        for(Case obj:[select id,ICY_Geographic_Area__c from Case where id in:setOfCaseIds ]){
            if(String.isNotBlank(obj.ICY_Geographic_Area__c)){  
                String queueName = '%'+obj.ICY_Geographic_Area__c.replace('-', ' ')+'%';
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
            
              mapOfCaseIdUserEmail.put(obj.id,toAddressess);
            }
        }



        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        Id orgwideEmailId = YTS_Utility.getICYOrgWideEmailAddressId();
        String subject = 'Incident Alert';

        for(Case obj:[select id,CaseNumber,Primary_Contact__c from Case where id in:mapOfCaseIdUserEmail.keyset()]){
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            String body = 'Hello, <br/><br/>There is a new critical incident note related to <a href="'+ System.URL.getSalesforceBaseUrl().toExternalForm()+'/'+obj.id+'">'+obj.CaseNumber+'</a>. Please review as soon as possible. <br/><br/>Thank you.';
            //Change with Template ID
            mail.setTargetObjectId(UserInfo.getUserId());
            //Record ID for which letter will be generated
            mail.setSubject(subject);
            mail.setHtmlBody(body);
            if(orgwideEmailId != null) mail.setOrgWideEmailAddressId(orgwideEmailId);
            mail.setToAddresses(mapOfCaseIdUserEmail.get(obj.Id));
            mail.setBccSender(false);
            mail.setUseSignature(false);
            mail.setSaveAsActivity(false);
            emails.add(mail);
        }
        if(!Test.isRunningTest())
        Messaging.sendEmail(emails);
    }
}