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
           String  sPL='';
           List<String> lstEmails = new List<String>();
           sPL=ICY_Referral_Controller.getICYPlId(obj.ICY_Geographic_Area__c);
           if (sPL <> null){
            User objUser=[select id,Email from user where  id=:sPL];
            lstEmails.add(objUser.Email);
            mapOfCaseIdUserEmail.put(obj.id,lstEmails);
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