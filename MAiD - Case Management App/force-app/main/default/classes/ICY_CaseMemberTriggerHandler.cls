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
        
                
                if (String.isNotBlank(teamMemberUserId) ){
                        String emailId = [SELECT Email FROM USER WHERE ID=:teamMemberUserId].Email;
                        Messaging.SingleEmailMessage semail = new Messaging.SingleEmailMessage();
                        semail.setToAddresses(new List<String>{emailId});
                        // if(orgwideEmailId != null) semail.setOrgWideEmailAddressId(orgwideEmailId);
                        semail.setSubject('Case Assignment Notification');
                        String htmlBody = 'Hello,<br/>' + 'You have been added to case <a href="'+URL.getSalesforceBaseUrl().toExternalForm()+'/'+objCaseMember.ICY_Case__c+'">'+ref.Case__r.casenumber+'</a>.'+'</br> Please follow this link for details. <br/>' + 'Thank you';
                        semail.setHtmlBody(htmlBody);
                        Messaging.sendEmail(new Messaging.SingleEmailMessage[] {semail});
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