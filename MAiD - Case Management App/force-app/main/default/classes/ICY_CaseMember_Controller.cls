public without sharing class ICY_CaseMember_Controller {

    @AuraEnabled
    public static List<CaseMember> getAllCaseTeamMembers(String recordId){
        Id parentRecId = Id.ValueOf(recordId);
        List<CaseMember> result = new List<CaseMember>();
        List<Case_Member__c> cmList = new List<Case_Member__c>();
        Boolean hasRevokeAccess = false;

        String profileName = [SELECT Profile.Name FROM USER WHERE ID=:UserInfo.getUserId()].Profile.Name;
       // if(profileName == 'ICY Program Leader' || profileName == 'System Administrator') hasRevokeAccess = true;

        if (YTS_Utility.lookupRole('Program Leader') || YTS_Utility.lookupRole('Admin') || profileName == 'System Administrator') hasRevokeAccess = true;

        if(parentRecId.getSObjectType() == Schema.Referral__c.SObjectType){
            cmList = [SELECT Id, CreatedDate, ICY_Category_Assignment__c, ICY_End_Date__c, ICY_Status__c,ICY_User__r.Name,ICY_User__r.CompanyName, ICY_User__r.title, ICY_Case_Contact__r.Contact_Full_Name__c,ICY_Case_Contact__r.Profession_Role__c,ICY_Case_Contact__r.Contact_Person_Profession_Role__c,ICY_Case_Contact__r.Relationship_Subtype__c,ICY_Case_Contact__r.Other_Relationship__c, ICY_Team_Member__c, CreatedBy.Name FROM Case_Member__c WHERE  Referral__c = :parentRecId ORDER By ICY_Status__c asc];
        }else if(parentRecId.getSObjectType() == Schema.Case.SObjectType){
            cmList = [SELECT Id, CreatedDate, ICY_Category_Assignment__c, ICY_End_Date__c, ICY_Status__c,ICY_User__r.Name, ICY_User__r.CompanyName, ICY_User__r.title,ICY_Case_Contact__r.Contact_Full_Name__c,ICY_Case_Contact__r.Profession_Role__c,ICY_Case_Contact__r.Contact_Person_Profession_Role__c,ICY_Case_Contact__r.Relationship_Subtype__c,ICY_Case_Contact__r.Other_Relationship__c, ICY_Team_Member__c, CreatedBy.Name FROM Case_Member__c WHERE  ICY_Case__c = :parentRecId ORDER By ICY_Status__c asc];
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
            cm.professionRole = (c.ICY_Case_Contact__r.Profession_Role__c!= null)&& (c.ICY_Case_Contact__r.Profession_Role__c!= 'Other')? c.ICY_Case_Contact__r.Profession_Role__c: c.ICY_Case_Contact__r.Contact_Person_Profession_Role__c ;
            cm.relationshipSubtypetype = (c.ICY_Case_Contact__r.Relationship_Subtype__c!='Other') ? c.ICY_Case_Contact__r.Relationship_Subtype__c : c.ICY_Case_Contact__r.Other_Relationship__c;
            cm.hasRevokeAccess = ((hasRevokeAccess || UserInfo.getUserId() == c.ICY_User__c) && c.ICY_Status__c == 'Active');
            cm.isSupplemntal = (cm.category=='Supplemental');
            cm.CompanyName= c.ICY_User__r.CompanyName;
            cm.Title=c.ICY_User__r.title;
            cm.isUser=c.ICY_Team_Member__c;
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
        @AuraEnabled public String relationshipSubtypetype{get;set;}
        @AuraEnabled public String professionRole{get;set;}
        @AuraEnabled public String CompanyName{get;set;}
        @AuraEnabled public String Title{get;set;}
        @AuraEnabled public String addedBy{get;set;}
        @AuraEnabled public Boolean hasRevokeAccess{get;set;}
        @AuraEnabled public Boolean isSupplemntal{get;set;}
        @AuraEnabled public Boolean isUser{get;set;}
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
        if (YTS_Utility.lookupRole('Program Leader') || YTS_Utility.lookupRole('Admin') || profileName == 'System Administrator')
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
        Set<Id> refIds = new Set<Id>();

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

             //Query All Related Referrals
            refIds.add(referralId); 

            //Create Intake Share Records
            if(intakeIds.size() > 0){
                createIntakeShare(intakeIds, cm.ICY_User__c, accessLevel);
            }
            //Create Case Share Records
            if(caseIds.size() > 0){
                createAccountShares(caseIds, cm.ICY_User__c, accessLevel);
            }
            //Create Referral Share Records
            if(refIds.size() > 0){
                createReferralShare(refIds, cm.ICY_User__c, accessLevel);
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
        Set<Id> refIds = new Set<Id>();

        //Query All Related Intakes
        for(Intake__c i: [SELECT ID from Intake__c WHERE Referral__c = :cm.Referral__c]){
            intakeIds.add(i.Id);
        }
        //Query All Related Cases
        for(Case c: [SELECT Id FROM CASE WHERE Referral__c = :cm.Referral__c]){
            caseIds.add(c.Id);
        }

        //Query All Related Referrals
        refIds.add(cm.Referral__c);

        //Create Intake Share Records
        if(intakeIds.size() > 0){
            removeIntakeShare(intakeIds, cm.ICY_User__c);
        }
        //Create Case Share Records
        if(caseIds.size() > 0){
            removeCaseShare(caseIds, cm.ICY_User__c);
        }
         //Create Referral Share Records
         if(refIds.size() > 0){
            removeRefShare(refIds, cm.ICY_User__c);
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
        List<AccountShare> updateShareRecords = new List<AccountShare>();
      
        Set<Id> setAccountId = new Set<Id>();  
        Map<Id, String> accShIdAccessMap = new Map<Id, String>();
        Map<Id, Id> accShIdAccIdMap = new Map<Id, Id>();
        
        Boolean bFound = false;

        List<Case> caseList= [SELECT Id, AccountId FROM Case WHERE ID IN :caseIds];
        for (Case c: caseList){
            setAccountId.add(c.AccountId);
        }
        List<AccountShare> accShList = [SELECT Id ,AccountId,AccountAccessLevel FROM AccountShare WHERE AccountId IN :setAccountId and UserOrGroupId = :userId];
        for (AccountShare accSh: accShList){
            accShIdAccIdMap.put(accSh.Id,accSh.AccountId);
            accShIdAccessMap.put(accSh.Id,accSh.AccountAccessLevel);
           
        }
       
        for (Case c: caseList){
            bFound = false;
             for (Id key : accShIdAccIdMap.keySet()) {
                if ((accShIdAccIdMap.get(key)== c.AccountId) && (accShIdAccessMap.get(key)!='All')) {
                    shareRecords.add(
                        new AccountShare(
                            AccountAccessLevel = accessLevel,
                            AccountId = c.AccountId,
                            CaseAccessLevel = accessLevel,
                            OpportunityAccessLevel = 'None',
                            UserOrGroupId = userId
                        )
                    );
                    bFound= true;
                    break;
                
                }
                if ((accShIdAccIdMap.get(key)== c.AccountId) && (accShIdAccessMap.get(key)=='All')) {                    
                    AccountShare accShare= new AccountShare();
                    accShare.Id = key;
                    accShare.CaseAccessLevel= accessLevel;
                    updateShareRecords.add(accShare);  
                    bFound= true;
                }
             }
              if (!bFound){
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
            }     
            
        INSERT shareRecords;
        update updateShareRecords;
    }

    @TestVisible
    private static void createReferralShare(Set<Id> refIds, Id userId, String accessLevel){
        List<Referral__Share> shareRecords = new List<Referral__Share>();
        for(Id i: refIds){
            shareRecords.add(
                new Referral__Share(
                    AccessLevel = accessLevel,
                    UserOrGroupId = userId,
                    RowCause = Schema.Referral__Share.RowCause.Case_Team_Member_Share__c,
                    ParentId = i
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
            AccountShare accsh = [SELECT Id ,AccountAccessLevel FROM AccountShare WHERE AccountId IN (SELECT AccountId FROM CASE WHERE ID IN :caseIds) and UserOrGroupId = :userId];
            if ((accsh != null)&& (accsh.AccountAccessLevel !='All')){
              DELETE [SELECT ID FROM AccountShare WHERE UserOrGroupId = :userId AND AccountId IN (SELECT AccountId FROM CASE WHERE ID IN :caseIds)];
            }
            if ((accsh != null)&& (accsh.AccountAccessLevel =='All')){
                accsh.CaseAccessLevel= 'none';
                update accsh; 
            }      
            }catch(Exception ex){
            System.debug('$$ Remove Case and Account Share exception: '+ex);
        }
    }

    @TestVisible
    private static void removeRefShare(Set<Id> refIds, Id userId){
        try{
            DELETE [SELECT ID FROM Referral__Share WHERE UserOrGroupId = :userId AND ParentId IN :refIds];
        }catch(Exception ex){
            System.debug('$$ Remove Referral Share exception: '+ex);
        }
    }

 //if case member is being inserted then need to update on Referral Field: which will be used for filter criteria on Referral List view
 public static void updateReferralTeamMemberIds(List<Case_Member__c> lstCaseMember, Boolean isDelete)
 {
     Set<Id> setRefId = new set<Id>(); 
     map<Id,Set<Id>> mapRefIdMembersIdA = new Map<id,Set<Id>>();
     map<Id,Set<Id>> mapRemoveRefIdMembersIdA = new Map<id,Set<Id>>();
     map<Id,Referral__c> mapRefIdRefrecB = new  map<Id,Referral__c>();
     List<Referral__c> updatedListReferrals =new List<Referral__c>();
     List<Referral__c> updatedListReferralsRemove =new List<Referral__c>();

     String existingValue;
     String updateTeamMembersId;
     
     //get set<Id> of Referral Ids from List of Case members
     for(Case_Member__c cm:lstCaseMember){
          setRefId.add(cm.Referral__c);
     }
     //Query Referral for Team_members_Id__c and Udpate mapRefIdRefrecB
     List<Referral__c> lstCmRef = [Select id,Team_members_Id__c
                                        from Referral__c where Id IN : setRefId];
      for(Referral__c cmRef:lstCmRef){
         mapRefIdRefrecB.put(cmRef.id,cmRef);
     }

     for(Case_Member__c cm:lstCaseMember){
       if (cm.ICY_Status__c=='Active' && cm.ICY_User__c!= null && !isDelete){
             if(mapRefIdMembersIdA.Containskey(cm.Referral__c)){
                 // If the key already exists, add the user Id to the existing Set
                 mapRefIdMembersIdA.get(cm.Referral__c).add(cm.ICY_User__c);
             } else {
                 // If the key doesn't exist, create a new Set and add the user Id
                 mapRefIdMembersIdA.put(cm.Referral__c, new Set<Id>{cm.ICY_User__c});
             }
         }

         //Inactive members should be removed
         if ((cm.ICY_Status__c=='Inactive' && cm.ICY_User__c!= null && !isDelete) || (isDelete)){
             if(mapRemoveRefIdMembersIdA.Containskey(cm.Referral__c)){
                 // If the key already exists, add the user Id to the existing Set
                 mapRemoveRefIdMembersIdA.get(cm.Referral__c).add(cm.ICY_User__c);
             } else {
                 // If the key doesn't exist, create a new Set and add the user Id
                 mapRemoveRefIdMembersIdA.put(cm.Referral__c, new Set<Id>{cm.ICY_User__c});
             }
         }
     }// end for
    
     for (Id parentId : mapRefIdMembersIdA.keySet()) {
         Referral__c refRec=mapRefIdRefrecB.get(parentId);
         existingValue =refRec.Team_members_Id__c; 
         updateTeamMembersId='';
         // Get the Set of Ids for the current key
         Set<Id> childIds = mapRefIdMembersIdA.get(parentId);
         // Loop through the Set of Ids
         for (Id childId : childIds) {
             updateTeamMembersId = updateTeamMembersId(childId,existingValue);
             existingValue = updateTeamMembersId;
         }
         refRec.Team_members_Id__c = updateTeamMembersId;
         updatedListReferrals.add(refRec);
     }

     //Ids to be removed
     for (Id parentId : mapRemoveRefIdMembersIdA.keySet()) {
         Referral__c refRec=mapRefIdRefrecB.get(parentId);
         existingValue =refRec.Team_members_Id__c; 
         updateTeamMembersId='';

         // Get the Set of Ids for the current key
         Set<Id> childIds = mapRemoveRefIdMembersIdA.get(parentId);
         // Loop through the Set of Ids
         for (Id childId : childIds) {
             updateTeamMembersId=removeTeamMembersId(existingValue,childId);
             existingValue = updateTeamMembersId;
         }
         refRec.Team_members_Id__c = updateTeamMembersId;
         updatedListReferralsRemove.add(refRec);
     }

     // Perform a bulk update at the end
     if (!updatedListReferrals.isEmpty()) {
         update updatedListReferrals;
     }

       // Perform a bulk update at the end
       if (!updatedListReferralsRemove.isEmpty()) {
         update updatedListReferralsRemove;
     }
  }
       
  
  public static String updateTeamMembersId(String newValue, String existingValue) {
     String updatedValue = existingValue;
     // Check if the field is empty or has values
     if (String.isBlank(updatedValue)) {
         updatedValue = newValue;
     } else {
         // Convert the CSV string into a Set to prevent duplicates
         Set<String> csvSet = new Set<String>(updatedValue.split(','));  
         // Add the new value
         csvSet.add(newValue);   
         // Convert the Set back into a comma-separated string
         updatedValue = String.join(new List<String>(csvSet), ',');
     }    
     return updatedValue;
 }

 public static String removeTeamMembersId(String existingValue, String valueToRemove) {
     String updatedValue;
     if (!String.isBlank(existingValue)) {
         Set<String> csvSet = new Set<String>(existingValue.split(','));
         if (csvSet.contains(valueToRemove)) {
             csvSet.remove(valueToRemove);
         }
         // Convert the Set back into a comma-separated string
         updatedValue = String.join(new List<String>(csvSet), ',');
     }
     return updatedValue;
    }


   //Update Case team Size on Case when a team member is added
    public static void updateCaseTeamSize(List<Case_Member__c> lstCaseMember)
    {   
        map<Id,Set<Id>> mapCaseIdMembersIdA = new Map<id,Set<Id>>();
        map<Id,Integer> mapCaseIdTeamSizeCount = new Map<id,Integer>();
        List<Case> ListCasesToUpdate =new List<Case>();
        Set<Id> setCaseId = new set<Id>();
        map<Id,Case> mapCaseIdCaseRecB = new  map<Id,Case>();
        Id teamId;
        String sRole;
        Boolean bSelect = true;
        Set<Id> userIds = new Set<Id>();

        //Get the UserRole,name for all cm.ICY_Team_Member__c
        for(Case_Member__c cm:lstCaseMember){
            if (cm.ICY_Team_Member__c){
                userIds.add(cm.ICY_User__c);
            }
        }

        // Query Account fields using the IDs collected
        Map<Id, User> usersMap = new Map<Id, User>(
            [SELECT Id, UserRole.name FROM User WHERE Id IN :userIds]
        );
      
           
        //get set<Id> of ICY_Case__c  Ids from List of Case members
        for(Case_Member__c cm:lstCaseMember){
            //Wen team member is ICY_Team_Member__c exclude Role admin
            if (cm.ICY_User__c!= null){
              sRole= usersMap.get(cm.ICY_User__c).UserRole.name;
              if (sRole !=null){
                    sRole = sRole.toLowerCase(); 
                if (!(sRole.contains('admin')))
                    setCaseId.add(cm.ICY_Case__c);
              }
              else {
                setCaseId.add(cm.ICY_Case__c);
              }
            }
            else {
                setCaseId.add(cm.ICY_Case__c);
            }
        }
        //Query Case for Case_Team_Size__c and Udpate mapCaseIdCaseRecB
        List<Case> lstCases = [Select id,Case_Team_Size__c
		     							  from Case where Id IN : setCaseId];
         for(Case cmCase:lstCases){
            mapCaseIdCaseRecB.put(cmCase.id,cmCase);
        }

        //Query Case_Member__c for the setCaseId 
        List<Case_Member__c> lstCm = [Select id,ICY_User__c,ICY_User__r.UserRole.name,ICY_Case_Contact__c,ICY_Case__c
                                           from Case_Member__c where ICY_Case__c IN : setCaseId];
    
        for(Case_Member__c cm:lstCm){
            teamId= cm.ICY_User__c!=null? cm.ICY_User__c: cm.ICY_Case_Contact__c;
            bSelect = true;
            if (cm.ICY_User__c!= null){
              sRole= cm.ICY_User__r.UserRole.name;
                if (sRole !=null){
                    sRole = sRole.toLowerCase(); 
                    bSelect= (!(sRole.contains('admin'))) ? true : false;
                }
            }
            if (bSelect) {
                if(mapCaseIdMembersIdA.Containskey(cm.ICY_Case__c)){
                    // If the key already exists, add the user Id to the existing Set
                    mapCaseIdMembersIdA.get(cm.ICY_Case__c).add(teamId);
                } else {
                    // If the key doesn't exist, create a new Set and add the user Id
                    mapCaseIdMembersIdA.put(cm.ICY_Case__c, new Set<Id>{teamId});
                }
                }
        }

        Integer teamSize = 0;
        for (Id key : mapCaseIdMembersIdA.keySet()) {
            Set<Id> membersSet = mapCaseIdMembersIdA.get(key);
            teamSize= membersSet.size();
            mapCaseIdTeamSizeCount.put(key,teamSize);
        }
              
        for (Id caseId : mapCaseIdTeamSizeCount.keySet()) {
            Case caseRec=mapCaseIdCaseRecB.get(caseId); 
            caseRec.Case_Team_Size__c = mapCaseIdTeamSizeCount.get(caseId);
            ListCasesToUpdate.add(caseRec);
        }
        // Perform a bulk update at the end
        if (!ListCasesToUpdate.isEmpty()) {
            update ListCasesToUpdate;
        }
     }
    
}