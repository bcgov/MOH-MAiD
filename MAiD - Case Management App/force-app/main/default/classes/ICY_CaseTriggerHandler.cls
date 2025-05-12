public  class ICY_CaseTriggerHandler {
    /*public static void sendClosedCaseEmailNotificationToLead(List<Case> caseList, Map<Id,Case> oldcaseMap){
        Id standardCaserecordType = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('ICY_Standard_Case').getRecordTypeId();
        List<Case> casetoProcess= new List<Case>();
        Id orgwideemailId = YTS_Utility.getICYOrgWideEmailAddressId();
        system.debug('@@1');
        for(Case c: caseList){
            if(oldcaseMap.get(c.Id).Status<>c.Status &&
                c.Status=='Closed' &&
                String.isNotBlank(c.ICY_Geographic_Area__c)){
                casetoProcess.add(c);
            }
        }
        if(casetoProcess.isEmpty()){
            system.debug('@@2');
            return;
        }else{
            system.debug('@@3');
            Set<String> queueNames = new Set<String>();
            Case  caseObject = new Case ();

            for(Case c: casetoProcess){
                queueNames.add('%'+c.ICY_Geographic_Area__c);
                caseObject = c;
            }
            system.debug('@@4'+caseObject);
            Set<String> toAddressess = new Set<String>();
            Set<Id> groupOrQueuId = new Set<Id>();
            Set<Id> roleId = new Set<Id>();
            Set<Id> userid = new Set<Id>();
            For(GroupMember gm: [SELECT UserOrGroupId FROM GroupMember WHERE Group.Type = 'Queue' AND Group.Name LIKE :queueNames]){
                if((String.valueOf(gm.UserOrGroupId)).startsWithIgnoreCase('00G')){
                    groupOrQueuId.add(gm.UserOrGroupId);
                }else{
                    userid.add(gm.UserOrGroupId);
                }
            }
            system.debug('groupOrQueuId'+groupOrQueuId);
            system.debug('userid'+userid);
            if(!groupOrQueuId.isEmpty()){
                For(Group gm: [SELECT RelatedId,Type,DeveloperName FROM group WHERE Id IN:groupOrQueuId AND Type = 'Role']){
                    if(gm.Type=='Role'){
                        roleId.add(gm.RelatedId);
                    }
                }
            }
            system.debug('roleId'+roleId);
            user whoClosed;
            if(!roleId.isEmpty() || !userid.isEmpty()){
                For(User u: [SELECT Id,Name, email FROM User WHERE (UserRoleId =: roleId OR ID IN:userid OR ID =:caseObject.ICY_Closed_By__c) AND isActive = true]){
                    if(String.isBlank(caseObject.ICY_Closed_By__c) ||
                        u.Id != caseObject.ICY_Closed_By__c){
                        toAddressess.add(u.email);
                    }
                    if(U.id == caseObject.ICY_Closed_By__c){
                        whoClosed = U;
                    }
                }
            }
            if(Test.isRunningTest()) whoClosed = [SELECT Id,Name, email FROM User WHERE ID= :UserInfo.getUserId()] ;
            system.debug('whoClosed'+whoClosed);
            system.debug('toAddressess'+toAddressess);
            String Recordlink = URL.getSalesforceBaseUrl().toExternalForm()+'/'+caseObject.id;
            if(!toAddressess.isEmpty()){
                List<String> toAddressList = new List<String>();
                toAddressList.addAll(toAddressess);
                Messaging.SingleEmailMessage semail = new Messaging.SingleEmailMessage();
                semail.setToAddresses(toAddressList);
                if(orgwideEmailId != null) semail.setOrgWideEmailAddressId(orgwideEmailId);
                semail.setSubject('Case#'+caseObject.CaseNumber+' has been Closed');
                String htmlBody= 'Hi,</br>'+'The Case record <a href="'+Recordlink+'">'+caseObject.CaseNumber+'</a> has been Closed by '+whoClosed.Name;
                semail.setHtmlBody(htmlBody);
                system.debug('@@semail'+semail);
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] {semail});
            }

        }

    }*/
}