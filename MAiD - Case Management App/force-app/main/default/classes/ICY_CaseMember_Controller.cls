public without sharing class ICY_CaseMember_Controller {

    @AuraEnabled
    public static List<CaseMember> getAllCaseTeamMembers(String recordId){
        Id parentRecId = Id.ValueOf(recordId);
        List<CaseMember> result = new List<CaseMember>();
        List<Case_Member__c> cmList = new List<Case_Member__c>();
        Boolean hasRevokeAccess = false;

        String profileName = [SELECT Profile.Name FROM USER WHERE ID=:UserInfo.getUserId()].Profile.Name;
       // if(profileName == 'ICY Program Leader' || profileName == 'System Administrator') hasRevokeAccess = true;

        if (YTS_Utility.lookupRole('Program Leader') || YTS_Utility.lookupRole('Team Admin') || profileName == 'System Administrator') hasRevokeAccess = true;

        if(parentRecId.getSObjectType() == Schema.Referral__c.SObjectType){
            cmList = [SELECT Id, CreatedDate, ICY_Category_Assignment__c, ICY_End_Date__c, ICY_Status__c,ICY_User__r.Name, ICY_Case_Contact__r.Contact_Full_Name__c, ICY_Team_Member__c, CreatedBy.Name FROM Case_Member__c WHERE  Referral__c = :parentRecId ORDER By ICY_Status__c asc];
        }else if(parentRecId.getSObjectType() == Schema.Case.SObjectType){
            cmList = [SELECT Id, CreatedDate, ICY_Category_Assignment__c, ICY_End_Date__c, ICY_Status__c,ICY_User__r.Name, ICY_Case_Contact__r.Contact_Full_Name__c, ICY_Team_Member__c, CreatedBy.Name FROM Case_Member__c WHERE  ICY_Case__c = :parentRecId ORDER By ICY_Status__c asc];
        }

        for(Case_Member__c c: cmList){
            CaseMember cm = new CaseMember();
            cm.recordId = c.Id;
            cm.UserOrContactName = String.isNotBlank(c.ICY_User__r.Name)?c.ICY_User__r.Name: c.ICY_Case_Contact__r.Contact_Full_Name__c;
            cm.status = c.ICY_Status__c;
            cm.statusBadgeClass = c.ICY_Status__c == 'Active'?'slds-theme_success':'slds-theme_warning';
            cm.category = c.ICY_Category_Assignment__c;
            cm.categoryBadgeClass = 'slds-badge';
            cm.dateAdded = YTS_Utility.dateFormat_MMMdyyyykma(c.CreatedDate);
            cm.endDate = YTS_Utility.dateFormat_eeeeMMMdyyyy(c.ICY_End_Date__c);
            cm.isICYTeamMember = c.ICY_Team_Member__c?'Yes':'No';
            cm.addedBy = c.CreatedBy.Name;
            cm.hasRevokeAccess = ((hasRevokeAccess || UserInfo.getUserId() == c.ICY_User__c) && c.ICY_Status__c == 'Active');
            result.add(cm);
        }
        return result;
    }


    @AuraEnabled
    public static Boolean showSelfAccessButton(String recordId){
        List<Case_Member__c> cmList = new List<Case_Member__c>();
        Id parentRecId = Id.valueOf(recordId);
        String profileName = [SELECT Profile.Name FROM USER WHERE ID=:UserInfo.getUserId()].Profile.Name;
      //  if(profileName == 'ICY Program Leader' || profileName == 'System Administrator'){
        if (YTS_Utility.lookupRole('Program Leader') || profileName == 'System Administrator'){
            return false;
        }

        if(parentRecId.getSObjectType() == Schema.Referral__c.SObjectType){
            cmList = [SELECT Id  FROM Case_Member__c WHERE  Referral__c = :parentRecId AND ICY_Status__c = 'Active' AND ICY_User__c = :UserInfo.getUserId()];
        }else if(parentRecId.getSObjectType() == Schema.Case.SObjectType){
            cmList = [SELECT Id FROM Case_Member__c WHERE  ICY_Case__c = :parentRecId AND ICY_Status__c = 'Active' AND ICY_User__c = :UserInfo.getUserId()];
        }

        return !(cmList.size() > 0);
    }


    public Class CaseMember{
        @AuraEnabled public String recordId{get;set;}
        @AuraEnabled public String UserOrContactName{get;set;}
        @AuraEnabled public String userOrContactId{get;set;}
        @AuraEnabled public String status{get;set;}
        @AuraEnabled public String statusBadgeClass{get;set;}
        @AuraEnabled public String category{get;set;}
        @AuraEnabled public String categoryBadgeClass{get;set;}
        @AuraEnabled public String dateAdded{get;set;}
        @AuraEnabled public String endDate{get;set;}
        @AuraEnabled public String isICYTeamMember{get;set;}
        @AuraEnabled public String addedBy{get;set;}
        @AuraEnabled public Boolean hasRevokeAccess{get;set;}
    }

    //Create New Case Team Member
    @AuraEnabled
    public static String upsertCaseMember(Case_Member__c cm, String parentRecordId, String recordId, Boolean isSelfAccess){

        String result = 'SUCCESS';
        Id parentRecId = Id.ValueOf(parentRecordId);
        List<Case_Member__c> cmList = new List<Case_Member__c>();
        if(isSelfAccess) cm.ICY_User__c = UserInfo.getUserId();
        if (cm.ICY_Category_Assignment__c=='Supplemental'){
            if(parentRecId.getSObjectType() == Schema.Referral__c.SObjectType){
                cmList = [SELECT Id FROM Case_Member__c WHERE ICY_Case_Contact__c = :cm.ICY_Case_Contact__c AND ICY_Status__c = 'Active' AND Referral__c = :parentRecId];
            }else if(parentRecId.getSObjectType() == Schema.Case.SObjectType){
                cmList = [SELECT Id FROM Case_Member__c WHERE ICY_Case_Contact__c = :cm.ICY_Case_Contact__c AND ICY_Status__c = 'Active' AND ICY_Case__c = :parentRecId];
            }
        }
        else{
            //Validate if Case Member already Exists
            if(parentRecId.getSObjectType() == Schema.Referral__c.SObjectType){
                cmList = [SELECT Id FROM Case_Member__c WHERE ICY_User__c = :cm.ICY_User__c AND ICY_Status__c = 'Active' AND Referral__c = :parentRecId];
            }else if(parentRecId.getSObjectType() == Schema.Case.SObjectType){
                cmList = [SELECT Id FROM Case_Member__c WHERE ICY_User__c = :cm.ICY_User__c AND ICY_Status__c = 'Active' AND ICY_Case__c = :parentRecId];
            }
       }

       if(cmList != null && cmList.size() > 0) {
        String profileName = [SELECT Profile.Name FROM USER WHERE ID=:UserInfo.getUserId()].Profile.Name;
        if (YTS_Utility.lookupRole('Program Leader') || YTS_Utility.lookupRole('Team Admin') || profileName == 'System Administrator')
           revokeCaseTeamMemberAccess(cmList[0].id);
        else
           return System.label.ICY_TeamMemberExits ;
        }

        //Process if case Team member doesn't exist
        if(String.isNotBlank(recordId)) cm.Id = recordId;
        String accessLevel = 'Edit';
        String referralId;
        String caseId;
        Set<Id> intakeIds = new Set<Id>();
        Set<Id> caseIds = new Set<Id>();

        //Read Only Access For Consulting
        if(cm.ICY_Category_Assignment__c == 'Consulting') accessLevel = 'Read';

        if(parentRecId.getSObjectType() == Schema.Referral__c.SObjectType){
            cm.Referral__c = parentRecId;
            referralId = parentRecId;
            Referral__c r = [SELECT Case__c FROM Referral__c WHERE Id=:parentRecId];
            if(String.isNotBlank(r.Case__c)) cm.ICY_Case__c = r.Case__c;
        }else if(parentRecId.getSObjectType() == Schema.Case.SObjectType){
            Case c = [SELECT Id, Referral__c, AccountId FROM Case WHERE Id = :parentRecId];
            referralId = c.Referral__c;
            if(String.isBlank(referralId)){
                Referral__c r = [SELECT Id FROM Referral__c WHERE Case__c = :parentRecId];
                referralId = r.Id;
            }
            cm.Referral__c = referralId;
            cm.ICY_Case__c = parentRecId;
            caseIds.add(parentRecId);
        }

        UPSERT cm;

        //Create Sharing Records for The Assigned User
        if(String.isNotBlank(cm.ICY_User__c) && cm.ICY_Status__c == 'Active'){
            //Query All Related Intakes
            for(Intake__c i: [SELECT ID from Intake__c WHERE Referral__c = :referralId]){
                intakeIds.add(i.Id);
            }
            //Query All Related Cases
            for(Case c: [SELECT Id FROM CASE WHERE Referral__c = :referralId]){
                caseIds.add(c.Id);
            }

            //Create Intake Share Records
            if(intakeIds.size() > 0){
                createIntakeShare(intakeIds, cm.ICY_User__c, accessLevel);
            }
            //Create Case Share Records
            if(caseIds.size() > 0){
                createAccountShares(caseIds, cm.ICY_User__c, accessLevel);
            }
        }

        return result;
    }

    //Remove Case Team Member
    @AuraEnabled
    public static void revokeCaseTeamMemberAccess(String recordId){
        Case_Member__c cm = [SELECT ID, ICY_Status__c, Referral__c, ICY_Case__c, ICY_User__c FROM Case_Member__c WHERE ID = :recordId];
        cm.ICY_Status__c = 'Inactive';
        cm.ICY_End_Date__c = Date.Today();
        UPDATE cm;
        Set<Id> intakeIds = new Set<Id>();
        Set<Id> caseIds = new Set<Id>();

        //Query All Related Intakes
        for(Intake__c i: [SELECT ID from Intake__c WHERE Referral__c = :cm.Referral__c]){
            intakeIds.add(i.Id);
        }
        //Query All Related Cases
        for(Case c: [SELECT Id FROM CASE WHERE Referral__c = :cm.Referral__c]){
            caseIds.add(c.Id);
        }
        //Create Intake Share Records
        if(intakeIds.size() > 0){
            removeIntakeShare(intakeIds, cm.ICY_User__c);
        }
        //Create Case Share Records
        if(caseIds.size() > 0){
            removeCaseShare(caseIds, cm.ICY_User__c);
        }


    }

    @TestVisible
    private static void createIntakeShare(Set<Id> intakeIds, Id userId, String accessLevel){
        List<Intake__Share> shareRecords = new List<Intake__Share>();
        for(Id i: intakeIds){
            shareRecords.add(
                new Intake__Share(
                    AccessLevel = accessLevel,
                    UserOrGroupId = userId,
                    RowCause = Schema.Intake__Share.RowCause.Case_Team_Member_Share__c,
                    ParentId = i
                )
            );
        }
        INSERT shareRecords;
    }

    @TestVisible
    private static void createAccountShares(Set<Id> caseIds, Id userId, String accessLevel){
        List<AccountShare> shareRecords = new List<AccountShare>();
        for(Case c: [SELECT Id, AccountId FROM Case WHERE ID IN :caseIds]){
            shareRecords.add(
                new AccountShare(
                    AccountAccessLevel = accessLevel,
                    AccountId = c.AccountId,
                    CaseAccessLevel = accessLevel,
                    OpportunityAccessLevel = 'None',
                    UserOrGroupId = userId
                )
            );
        }

        INSERT shareRecords;
    }

    @TestVisible
    private static void removeIntakeShare(Set<Id> intakeIds, Id userId){
        try{
            DELETE [SELECT ID FROM Intake__Share WHERE UserOrGroupId = :userId AND ParentId IN :intakeIds];
        }catch(Exception ex){
            System.debug('$$ Remove Intake Share exception: '+ex);
        }
    }

    @TestVisible
    private static void removeCaseShare(Set<Id> caseIds, Id userId){
        try{
            DELETE [SELECT ID FROM AccountShare WHERE UserOrGroupId = :userId AND AccountId IN (SELECT AccountId FROM CASE WHERE ID IN :caseIds)];
        }catch(Exception ex){
            System.debug('$$ Remove Case and Account Share exception: '+ex);
        }
    }

}