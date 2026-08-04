public class ICY_CaseTriggerHandler {

    public static void sendClosedCaseEmailNotificationToLead(
        List<Case> caseList,
        Map<Id, Case> oldcaseMap
    ){
        Id standardCaseRecordTypeId = Schema.SObjectType.Case
            .getRecordTypeInfosByDeveloperName()
            .get('ICY_Standard_Case')
            .getRecordTypeId();

        Id orgWideEmailId = YTS_Utility.getICYOrgWideEmailAddressId();

        List<Messaging.SingleEmailMessage> emails =
            new List<Messaging.SingleEmailMessage>();

        for(Case caseObject : caseList){

            Case oldCase = oldcaseMap.get(caseObject.Id);

            if(oldCase == null ||
               oldCase.Status == caseObject.Status ||
               caseObject.Status != 'Closed' ||
               caseObject.RecordTypeId != standardCaseRecordTypeId ||
               String.isBlank(caseObject.ICY_Geographic_Area__c)){
                continue;
            }

            String plGroupName =
                getPLGroupDeveloperName(
                    caseObject.ICY_Geographic_Area__c
                );
		
            System.debug('plGroupName'+plGroupName);
            
            Set<Id> recipientUserIds = new Set<Id>();

            // Add only direct User members. Ignore all 00G members.
            for(GroupMember gm : [
                SELECT UserOrGroupId FROM GroupMember WHERE Group.DeveloperName = :plGroupName AND Group.Type = 'Regular'
            ]){
                if(String.valueOf(gm.UserOrGroupId).startsWith('005')){
                    recipientUserIds.add(gm.UserOrGroupId);
                }
            }

            Boolean ownerIsUser =
                String.valueOf(caseObject.OwnerId).startsWith('005');

            Id closedById = caseObject.ICY_Closed_By__c;

            if(ownerIsUser){
                recipientUserIds.add(caseObject.OwnerId);
            }

            // Exclude owner when the owner closed the Case
            if(ownerIsUser && caseObject.OwnerId == closedById){
                recipientUserIds.remove(caseObject.OwnerId);
            }

            Set<Id> userIdsToQuery = new Set<Id>();
            userIdsToQuery.addAll(recipientUserIds);

            if(closedById != null){
                userIdsToQuery.add(closedById);
            }

            if(userIdsToQuery.isEmpty()){
                continue;
            }

            Set<String> toAddresses = new Set<String>();
            User whoClosed;

            for(User userObject : [
                SELECT Id, Name, Email FROM User  WHERE Id IN :userIdsToQuery AND IsActive = true
            ]){
                if(userObject.Id == closedById){
                    whoClosed = userObject;
                }

                if(recipientUserIds.contains(userObject.Id) &&
                   String.isNotBlank(userObject.Email)){
                    toAddresses.add(userObject.Email);
                }
            }
			
            System.debug('toAddresses'+toAddresses);
            
            if(toAddresses.isEmpty()){
                continue;
            }

            String recordLink = URL.getOrgDomainUrl().toExternalForm() + '/' + caseObject.Id;
            String closedByName = whoClosed != null ? whoClosed.Name : 'a user';
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>(toAddresses));

            if(orgWideEmailId != null){
                email.setOrgWideEmailAddressId(orgWideEmailId);
            }

            email.setSubject('Case#' + caseObject.CaseNumber + ' has been Closed');

            email.setHtmlBody('Hi,<br/>' + 'The Case record <a href="' + recordLink + '">' +
                caseObject.CaseNumber + '</a> has been Closed by ' + closedByName
            );

            emails.add(email);
        }

        if(!emails.isEmpty()){
            Messaging.sendEmail(emails);
        }
    }
	
	
    private static String getPLGroupDeveloperName(
        String geographicArea
    ){
        String normalizedArea = geographicArea.trim();

        normalizedArea = normalizedArea.replace('-', ' ');
        normalizedArea = normalizedArea.replace('(', ' ');
        normalizedArea = normalizedArea.replace(')', ' ');
        normalizedArea = normalizedArea.replace(' Team ', ' ');
        normalizedArea = normalizedArea.replaceAll('\\s+[0-9]+$', '');
        normalizedArea = normalizedArea.replaceAll('\\s+', ' ').trim();
        
        if(normalizedArea.equalsIgnoreCase('qathet Powell River')){
            normalizedArea = 'Qathet Powell River';
        }

        return 'ICY_ACCESS_' + normalizedArea.replace(' ', '_') + '_PL';
    }
}