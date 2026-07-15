public class ICY_CaseTriggerHandler {
    public static void sendClosedCaseEmailNotificationToLead(List<Case> caseList, Map<Id,Case> oldcaseMap){
        Id standardCaserecordType = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('ICY_Standard_Case').getRecordTypeId();
        Id orgwideemailId = YTS_Utility.getICYOrgWideEmailAddressId();
        List<Case> casetoProcess = new List<Case>();

        for(Case c : caseList){
            if(oldcaseMap.get(c.Id).Status != c.Status &&
               c.Status == 'Closed' &&
               oldcaseMap.get(c.Id).RecordTypeId == standardCaserecordType &&
               String.isNotBlank(c.ICY_Geographic_Area__c)){
                casetoProcess.add(c);
            }
        }

        if(casetoProcess.isEmpty()){
            return;
        }

        Case caseObject = new Case();

        for(Case c : casetoProcess){
            caseObject = c;
        }

        String plGroupName = 'ICY_ACCESS_' + caseObject.ICY_Geographic_Area__c + '_PL';
        Set<Id> userIds = new Set<Id>();
        for(GroupMember gm : [SELECT UserOrGroupId FROM GroupMember WHERE Group.DeveloperName = :plGroupName AND Group.Type = 'Regular']){
            if(String.valueOf(gm.UserOrGroupId).startsWith('005')){
                userIds.add(gm.UserOrGroupId);
            }
        }
		System.debug('plGroupName='+plGroupName); 
        Boolean ownerIsUser = String.valueOf(caseObject.OwnerId).startsWith('005');
        if(ownerIsUser){
            userIds.add(caseObject.OwnerId);
        }

        Id closedById = caseObject.ICY_Closed_By__c;
        Boolean ownerIsClosing = ownerIsUser && closedById != null && closedById == caseObject.OwnerId;

        if(closedById != null){
            userIds.add(closedById);
        }
		System.debug('userIds='+userIds); 
        Set<String> toAddresses = new Set<String>();
        User whoClosed;
        for(User u : [SELECT Id, Name, Email FROM User WHERE Id IN :userIds AND IsActive = true]){
            if(u.Id == closedById){
                whoClosed = u;
            }
			
            Boolean isRecipient = (u.Id == caseObject.OwnerId && ownerIsUser) ||
                (u.Id != caseObject.OwnerId && userIds.contains(u.Id));

            if(!isRecipient){
                continue;
            }

            if(ownerIsClosing && u.Id == caseObject.OwnerId){
                continue;
            }

            toAddresses.add(u.Email);
        }
        System.debug('whoClosed='+whoClosed); 
		System.debug('toAddresses='+toAddresses);
        if(Test.isRunningTest()){
            whoClosed = [SELECT Id, Name, Email FROM User WHERE Id = :UserInfo.getUserId()];
        }
        if(!toAddresses.isEmpty()){
            String Recordlink = URL.getOrgDomainUrl().toExternalForm()+'/'+caseObject.Id;
            Messaging.SingleEmailMessage semail = new Messaging.SingleEmailMessage();
            semail.setToAddresses(new List<String>(toAddresses));
            if(orgwideemailId != null){
                semail.setOrgWideEmailAddressId(orgwideemailId);
            }
            semail.setSubject('Case#'+caseObject.CaseNumber+' has been Closed');
            semail.setHtmlBody('Hi,</br>The Case record <a href="'+Recordlink+'">'+caseObject.CaseNumber+'</a> has been Closed by '+(whoClosed != null ? whoClosed.Name : 'a user'));
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{semail}); 
        }
    }
}