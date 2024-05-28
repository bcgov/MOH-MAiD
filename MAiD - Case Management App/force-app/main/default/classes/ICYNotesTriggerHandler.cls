public with sharing class ICYNotesTriggerHandler{
    public static void doInsert(List<ICY_Notes__c> triggerNew){
        set<Id> setOfCaseIds = new set<Id>();
        for(ICY_Notes__c obj:triggerNew){
            if(obj.Referral_Subject__c == 'Critical Incident' && obj.Case__c!=null){
                setOfCaseIds.add(obj.Case__c);
            }
        }
        map<Id,List<String>> mapOfCaseIdVsUserIds = new map<Id,List<String>>();
        for(Case_Member__c obj:[select id,ICY_User__r.Email, ICY_Case__c from Case_Member__c where ICY_Case__c in:setOfCaseIds AND ICY_Category_Assignment__c != 'Supplemental' AND ICY_Status__c='Active']){
            List<String> userIds = new List<String>();
            if(mapOfCaseIdVsUserIds.containsKey(obj.ICY_Case__c)){
                userIds = mapOfCaseIdVsUserIds.get(obj.ICY_Case__c);
            }
            userIds.add(obj.ICY_User__r.Email);
            mapOfCaseIdVsUserIds.put(obj.ICY_Case__c,userIds);
        }
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        Id orgwideEmailId = YTS_Utility.getICYOrgWideEmailAddressId();
        String subject = 'Incident Alert';


        for(Case obj:[select id,CaseNumber,Primary_Contact__c from Case where id in:mapOfCaseIdVsUserIds.keyset()]){
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            String body = 'Hello, <br/><br/>There is a new critical incident note related to <a href="'+ System.URL.getSalesforceBaseUrl().toExternalForm()+'/'+obj.id+'">'+obj.CaseNumber+'</a>. Please review as soon as possible. <br/><br/>Thanks.';
            //Change with Template ID
            mail.setTargetObjectId(UserInfo.getUserId());
            //Record ID for which letter will be generated
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