public with sharing class ICYNotesTriggerHandler{
    public static void doInsert(List<ICY_Notes__c> triggerNew){
        set<Id> setOfCaseIds = new set<Id>();
        for(ICY_Notes__c obj:triggerNew){
            if(obj.Referral_Subject__c == 'Critical Incident' && obj.Case__c!=null){
                setOfCaseIds.add(obj.Case__c);
            }
        }
        //Getting all members Email except the current user who created the note 
        map<Id,List<String>> mapOfCaseIdVsUserIds = new map<Id,List<String>>();
        for(Case_Member__c obj:[select id,ICY_User__r.Id,ICY_User__r.Email, ICY_Case__c from Case_Member__c where ICY_Case__c in:setOfCaseIds AND ICY_Category_Assignment__c != 'Supplemental' AND ICY_Status__c='Active']){
            List<String> userIds = new List<String>();
           
          //  if (UserInfo.getUserId() <> obj.ICY_User__r.Id){
                if(mapOfCaseIdVsUserIds.containsKey(obj.ICY_Case__c) ){
                    userIds = mapOfCaseIdVsUserIds.get(obj.ICY_Case__c);
                }
                userIds.add(obj.ICY_User__r.Email);
                mapOfCaseIdVsUserIds.put(obj.ICY_Case__c,userIds);
           // }
        }
        //Adding PL
        for(Case obj:[select id,ICY_Geographic_Area__c from Case where id in:setOfCaseIds ]){
            List<String> userIds = new List<String>();
            if(String.isNotBlank(obj.ICY_Geographic_Area__c)){  
                String queueName = '%'+obj.ICY_Geographic_Area__c.replace('-', ' ')+'%';
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
                For(Group gm: [SELECT RelatedId,Type,DeveloperName FROM group WHERE Id IN:groupOrQueuId AND Type = 'Role'and (DeveloperName  like '%Program_Leader%' OR  DeveloperName  like '%Admin%')]){
                    roleId.add(gm.RelatedId);
                }
            }
            
            if(!roleId.isEmpty() || !userid.isEmpty()){
                For(User u: [SELECT Id,Name, email FROM User WHERE (UserRoleId =: roleId OR ID IN:userid ) AND isActive = true]){
                        if(mapOfCaseIdVsUserIds.containsKey(obj.id) ){
                            userIds = mapOfCaseIdVsUserIds.get(obj.id);
                        }
                        userIds.add(u.email);
                        mapOfCaseIdVsUserIds.put(obj.id,userIds);
                    }
                }
            }
        }

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        Id orgwideEmailId = YTS_Utility.getICYOrgWideEmailAddressId();
        String subject = 'Incident Alert';


        for(Case obj:[select id,CaseNumber,Primary_Contact__c from Case where id in:mapOfCaseIdVsUserIds.keyset()]){
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            String body = 'Hello, <br/><br/>There is a new critical incident note related to <a href="'+ System.URL.getSalesforceBaseUrl().toExternalForm()+'/'+obj.id+'">'+obj.CaseNumber+'</a>. Please review as soon as possible. <br/><br/>Thank you.';
            mail.setSubject(subject);
            mail.setHtmlBody(body);
            if(orgwideEmailId != null) mail.setOrgWideEmailAddressId(orgwideEmailId);
            mail.setToAddresses(mapOfCaseIdVsUserIds.get(obj.Id));
            mail.setBccSender(false);
            mail.setUseSignature(false);
            mail.setSaveAsActivity(false);
            emails.add(mail);
        }
        if(!Test.isRunningTest())
        Messaging.sendEmail(emails);
    }
}
