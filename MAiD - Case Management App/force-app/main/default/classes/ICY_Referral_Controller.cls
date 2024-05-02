public without sharing class ICY_Referral_Controller {

    /**
     * Get picklist values
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getPicklistvalues(String objectApiName, String fieldApiName){
        return YTS_Utility.getPicklistValues(objectApiName, fieldApiName);
    }

    //Get Record Type Id
    @AuraEnabled(cacheable=true)
    public static String getRecordTypeId(String objectApiName, String recordTypeDeveloperName){
        return YTS_Utility.getRecordTypeIdByDeveloperName(objectApiName, recordTypeDeveloperName);
    }

    //GetRecord Type from referral Record ID
    @AuraEnabled
    public static String getRecordTypeName(String recordId){
        String recordTypeName =  [SELECT Id, RecordType.Name FROM Referral__c WHERE ID=:recordId].RecordType.Name;
        System.debug('recordTypeName::'+recordTypeName);
        return recordTypeName;
    }

    //createPrimaryContact
    @AuraEnabled
    public static String createPrimaryContact(Case_Contact__c caseContact, String referralId){
        caseContact.RecordTypeId = YTS_Utility.getRecordTypeIdByDeveloperName('Case_Contact__c', 'ICY_Case_Contact');
        caseContact.Referral__c = referralId;
        INSERT caseContact;
        return caseContact.Id;
    }

    //Check if Current User is Part of Case Members
    @AuraEnabled
    public static Boolean isUserPartOfCaseMembers(String recordId){
        Referral__c r = [SELECT ID, OwnerId, ICY_Assigned_To__c FROM Referral__c WHERE Id =:recordId];
        User u = [SELECT ID, Profile.Name FROM USER WHERE Id=:UserInfo.getUserId()];
        // Ignore case member logic for System Admin, Program Leaders and User assigned in ICY Assigned To Field
       // if(u.Profile.Name == 'System Administrator' || u.Profile.Name == 'ICY Program Leader' || u.Profile.Name == 'ICY Administrator' || u.Profile.Name == 'ICY Clinical Team Member' || u.Profile.Name == 'ICY Non Clinical Team Member' || u.Id == r.ICY_Assigned_To__c){
        if (YTS_Utility.lookupRole('Program Leader') || u.Profile.Name == 'System Administrator' || YTS_Utility.lookupRole('Admin') || YTS_Utility.lookupRole('Clinical Member') || YTS_Utility.lookupRole('Non Clinical Member') || u.Id == r.ICY_Assigned_To__c){  
            return true;
        }
        List<Case_Member__c> caseMembers = [SELECT ID FROM Case_Member__c WHERE Referral__c = :recordId AND ICY_User__c=:UserInfo.getUserId() AND ICY_Status__c='Active'];
        if(caseMembers != null && caseMembers.size() > 0) return true;

        return false;
    }

    //update referral Owner to queue
    @AuraEnabled
    public static String getICYQueueId(String geographicArea){
        geographicArea = geographicArea.replace('-', ' ');
        String geoArea = '%'+geographicArea+'%';
        List<Group> groupList = [SELECT ID FROM GROUP WHERE TYPE='Queue' AND Name LIKE :geoArea LIMIT 1];
        return groupList[0].Id;
    }

    //update referral PL id 
    @AuraEnabled
    public static String getICYPlId(String geographicArea){
        geographicArea = geographicArea.replace('-', ' ');
        String geoArea = '%'+geographicArea+'%';
        List<Group> groupList = [SELECT ID FROM GROUP WHERE TYPE='Queue' AND Name LIKE :geoArea LIMIT 1];
        
        List<Group> groupList2=[select developername  from group where id in (select  UserOrGroupId from groupmember where groupId =:groupList[0].Id) and 
                                type='Role'  and DeveloperName  like '%Program_Leader%' ];                  
               
        List<User> userList=[select id from user where  UserRoleId in (select id from userrole where developername=:groupList2[0].developername)];
        return userList[0].Id;
    }

    //checkIfHealthNumberIsUnique
    @AuraEnabled
    public static Boolean checkIfHealthNumberIsUnique(String phn){
        List<Referral__c> r = [SELECT ID FROM Referral__c WHERE ICY_Personal_Health_Number__c =: phn];
        if(r != null && r.size() > 0) return false;
        return true;
    }

    //Create ICY Intake
    @AuraEnabled
    public static string createICYIntakeRecord(String referralId){
        try {
            String currentUserProfileName = [SELECT Id, Profile.Name from user where id=:UserInfo.getUserId()].Profile.Name;
            
            Referral__c r = [SELECT Id, Status__c, OwnerId,ICY_Assigned_To__c  FROM Referral__c WHERE ID=:referralId];
            r.Status__c = 'Ready for Intake';
            UPDATE r;
            String assignedTo = currentUserProfileName != 'System Administrator'?UserInfo.getUserId():'';
            Intake__c i = new Intake__c();
            i.recordTypeId = YTS_Utility.getRecordTypeIdByDeveloperName('Intake__c', 'ICY_Intake');
            i.ownerId = r.OwnerId;
            i.Referral__c = referralId;
            if(String.isNotBlank(assignedTo)) i.ICY_Assigned_To__c = assignedTo;
            INSERT i;
            
            List<ICY_Document__c> docsToUpdate = new List<ICY_Document__c>();
            List<Case_Contact__c> consToUpdate = new List<Case_Contact__c>();
            //Update Referral documents with Intake Id
            for(ICY_Document__c d: [SELECT Id FROM ICY_Document__c WHERE Referral__c = :referralId ]){
                d.Intake__c = i.Id;
                docsToUpdate.add(d);
            }
            //Update Referral Contacts with Intake Id
            for(Case_Contact__c cc: [SELECT Id FROM Case_Contact__c WHERE Referral__c = :referralId]){
                cc.Intake__c = i.Id;
                consToUpdate.add(cc);
            }
            if(docsToUpdate.size() > 0) UPDATE docsToUpdate;
            if(consToUpdate.size() > 0) UPDATE consToUpdate;

            User u = [SELECT Id, Profile.Name FROM User Where ID =:UserInfo.getUserId()];

            List<Intake__Share> intakeShares = new List<Intake__Share>();


            //if(!(u.Profile.Name == 'System Administrator' || u.Profile.Name == 'ICY Program Leader')){
            if (!(u.Profile.Name == 'System Administrator' || YTS_Utility.lookupRole('Program Leader'))){
                //Provide Access To the ICY user that Accepted teh Referral
                intakeShares.add(
                    new Intake__Share(accessLevel = 'Edit', parentId = i.Id,RowCause = Schema.Intake__Share.RowCause.Case_Team_Member_Share__c, UserOrGroupId = UserInfo.getUserId())
                );
            }

            //Provide Access To All the Team Members Of Referral
            for(Case_Member__c cm: [SELECT ID, ICY_User__c,ICY_Category_Assignment__c FROM 
                                        Case_Member__c WHERE ICY_User__c != NULL AND ICY_Status__c = 'Active'
                                        AND Referral__c = :referralId]){
                intakeShares.add(
                    new Intake__Share(
                       accessLevel = (cm.ICY_Category_Assignment__c == 'Consulting')?'Read':'Edit',parentId = i.Id,RowCause = 'Manual',UserOrGroupId = cm.ICY_User__c )
                );
            }

            if(intakeShares.size() > 0) INSERT intakeShares;
            
            
            return i.Id;
        } catch (Exception e) {
            System.debug('$$ Exception: '+e.getStackTraceString()+'\n'+e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }

    }

    
}