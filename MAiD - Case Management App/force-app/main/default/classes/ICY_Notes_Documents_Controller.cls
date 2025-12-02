/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 04-25-2022
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class ICY_Notes_Documents_Controller {
    public ICY_Notes_Documents_Controller() {

    }


    /**
     * Retrieve Related Notes From either Referral/Case/Intake Records
     */
    @AuraEnabled
    public static List<Note> getRelatedNotes(String recordId, Boolean sortDirection,String filter, Boolean adminNotes){
        system.debug('@@1');
        Id parentRecordId = Id.valueOf(recordId);
        List<Note> result = new List<Note>();
        List<ICY_Notes__c> caseNotes = new List<ICY_Notes__c>();
        Boolean isProgramLeader = false;
        final String ADMIN_NOTES_TYPE = 'Administrative Notes';

        if(parentRecordId.getSobjectType() == Schema.Referral__c.SObjectType)
            caseNotes = [SELECT ID, Name, UserRecordAccess.HasEditAccess, UserRecordAccess.HasDeleteAccess, 
                            Description__c,ICY_Meeting_Date__c, Referral_Subject__c, CreatedDate, CreatedBy.Name,CreatedById, LastModifiedDate, LastModifiedBy.Name,
                            Notes_Type__c,Other__c, Attendees__c, Length_of_Meeting__c,Note_source__c
                            FROM ICY_Notes__c WHERE Referral__c = :parentRecordId ORDER BY CreatedDate desc];
        else if(parentRecordId.getSobjectType() == Schema.Case.SObjectType){
            String caseNotesQuery = 'SELECT ID, Name, UserRecordAccess.HasEditAccess, UserRecordAccess.HasDeleteAccess, Description__c,ICY_Meeting_Date__c, Referral_Subject__c,Mode_Location__c,Other_Mode_Location__c,Team_Member__c, CreatedDate, CreatedBy.Name, LastModifiedDate, LastModifiedBy.Name, Notes_Type__c,Other__c, Attendees__c, Length_of_Meeting__c,Note_Source__c FROM ICY_Notes__c WHERE Case__c =:parentRecordId';
            if(adminNotes){
                caseNotesQuery += ' AND Notes_Type__c = :ADMIN_NOTES_TYPE';
            }else{
                caseNotesQuery += ' AND Notes_Type__c != :ADMIN_NOTES_TYPE';
            }

            if(String.isNotBlank(filter))
                caseNotesQuery = caseNotesQuery+' AND Referral_Subject__c =:filter';
            if(sortDirection){
                caseNotesQuery = caseNotesQuery+' ORDER BY CreatedDate asc';
            }
            else
                caseNotesQuery = caseNotesQuery+' ORDER BY CreatedDate desc'; 

            caseNotes = database.Query(caseNotesQuery);
        }
        else if(parentRecordId.getSobjectType() == Schema.Intake__c.SObjectType)
            caseNotes = [SELECT ID, Name, UserRecordAccess.HasEditAccess, UserRecordAccess.HasDeleteAccess, 
            Description__c,ICY_Meeting_Date__c, Referral_Subject__c, CreatedDate, CreatedBy.Name,CreatedById, LastModifiedDate, LastModifiedBy.Name,
            Notes_Type__c,Other__c, Attendees__c,Length_of_Meeting__c,Note_Source__c FROM ICY_Notes__c WHERE Intake__c = :parentRecordId ORDER BY CreatedDate desc];


        // verify the role for the current running user if he is a Program leader
        isProgramLeader = YTS_Utility.lookupRole('Program Leader');

        for(ICY_Notes__c n: caseNotes){
            String subject = n.Referral_Subject__c == 'Other' ? n.Other__c: n.Referral_Subject__c;
            String modifiedDate = YTS_Utility.dateFormat_eeeeMMMdyyyy(n.LastModifiedDate);
            String createdDate = YTS_Utility.dateFormat_eeeeMMMdyyyy(n.CreatedDate);
            String badgeCSS = n.Notes_Type__c == 'Restricted'?'slds-theme_warning':'slds-theme_success';
            String teamMember = parentRecordId.getSobjectType() == Schema.Case.SObjectType?n.Team_Member__c:'';
            String modeLocation = parentRecordId.getSobjectType() == Schema.Case.SObjectType?n.Mode_Location__c:'';
            String otherModeLocation = parentRecordId.getSobjectType() == Schema.Case.SObjectType?n.Other_Mode_Location__c:'';
            String noteSource = String.isBlank(n.Note_Source__c) ?'Case':n.Note_Source__c;
           
           // To be able to Edit a note either you are the creator of the notes or the PL and the note type shouldn't be = Restricted
            Boolean canEdit = (((n.CreatedById == UserInfo.getUserId()) || isProgramLeader ) && (n.Notes_Type__c=='Collaborative'))? true : false;
            
            result.add(
                new Note(
                    n.Id,
                    n.Name,
                    n.Notes_Type__c,
                    n.Referral_Subject__c == 'Other' ? n.Other__c: n.Referral_Subject__c,
                    n.Description__c,
                    n.ICY_Meeting_Date__c,
                    n.Attendees__c,
                    n.Length_of_Meeting__c,
                    modifiedDate,
                    n.LastModifiedBy.Name,
                    createdDate,
                    n.createdBy.Name,
                    badgeCSS,
                    teamMember,
                    modeLocation,
                    otherModeLocation,
                    noteSource,
                    Schema.sObjectType.ICY_Notes__c.isUpdateable(),
                    Schema.sObjectType.ICY_Notes__c.isDeletable(),
                    canEdit
                )
            );
        }
         system.debug('@@2'+result);
        return result;
    }


    /**
     * Retrieve Related Document Records From either Referral/Case/Intake Records
     */
    @AuraEnabled
    public static ParentwithDocument getRelatedDocuments(String recordId){
        Id parentRecordId = Id.valueOf(recordId);
        List<Document> result  = new List<Document>();
        Map<Id, ICY_Document__c> docs = new Map<Id, ICY_Document__c>();
        ParentwithDocument retData = new ParentwithDocument();
        
        if(parentRecordId.getSobjectType() == Schema.Referral__c.SObjectType) {
            docs = new Map<Id, ICY_Document__c>([SELECT Id, Name, UserRecordAccess.HasEditAccess, UserRecordAccess.HasDeleteAccess, Category__c, Sub_Category__c, Description__c, Document_Key_Words__c, CreatedDate, CreatedBy.Name, 
                                                    LastModifiedDate, LastModifiedBy.Name, CreatedById,Document_Type__c,Other_Document_Type__c, (SELECT Id, Name FROM ATTACHMENTS)  
                                                    FROM ICY_Document__c Where Referral__c = :parentRecordId  ORDER BY CreatedDate desc]);
            String parentStatus = [select Id, Status__c from Referral__c where id=:parentRecordId].Status__c;
            retData.isParentCompleted = parentStatus != 'Referral';
        }
        else if(parentRecordId.getSobjectType() == Schema.Case.SObjectType)
            docs = new Map<Id, ICY_Document__c>([SELECT Id, Name, UserRecordAccess.HasEditAccess, UserRecordAccess.HasDeleteAccess, Category__c, Sub_Category__c, Description__c, Document_Key_Words__c, CreatedDate, CreatedBy.Name, 
                                                    LastModifiedDate, LastModifiedBy.Name, CreatedById,Document_Type__c, Other_Document_Type__c, (SELECT Id, Name FROM ATTACHMENTS) 
                                                    FROM ICY_Document__c Where Case__c = :parentRecordId ORDER BY CreatedDate desc]);
        else if(parentRecordId.getSobjectType() == Schema.Intake__c.SObjectType) {
            docs = new Map<Id, ICY_Document__c>([SELECT Id, Name, UserRecordAccess.HasEditAccess, UserRecordAccess.HasDeleteAccess, Category__c, Sub_Category__c, Description__c, Document_Key_Words__c, CreatedDate, CreatedBy.Name, 
                                                    LastModifiedDate, LastModifiedBy.Name,CreatedById,Document_Type__c, Other_Document_Type__c, (SELECT Id, Name FROM ATTACHMENTS)  
                                                    FROM ICY_Document__c Where Intake__c = :parentRecordId ORDER BY CreatedDate desc]);
            String parentStatus = [select Id, Status__c from Intake__c where id=:parentRecordId].Status__c;
            retData.isParentCompleted = parentStatus == 'Complete' || parentStatus == 'Closed';
        }
        
        Map<Id, Id> cdlMap = new Map<Id, Id>();
        Map<Id, Attachment> attachmentMap = new Map<Id, Attachment>();

        if(docs.size() > 0){
            //Pull Content Document
            for(ContentDocumentLink cdl: [SELECT ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId IN :docs.KeySet() ]){
                cdlMap.put(cdl.LinkedEntityId, cdl.ContentDocumentId);
            }
            //Pull Attachments Data that is prior to MVP-1 release
            for(Attachment a: [SELECT ID, ParentId FROM Attachment WHERE ParentId IN :docs.KeySet()]){
                attachmentMap.put(a.ParentId, a);
            }

            for(ICY_Document__c d: docs.values()){
                Boolean isAttach = false;
                String modifiedDate = YTS_Utility.dateFormat_eeeeMMMdyyyy(d.LastModifiedDate);
                String createdDate = YTS_Utility.dateFormat_eeeeMMMdyyyy(d.CreatedDate);
                String badgeCSS = d.Document_Type__c == 'Restricted'?'slds-theme_warning':'slds-theme_success';
                String category = d.Category__c == 'Other'?d.Other_Document_Type__c:d.Category__c;
                 // To be able to Edit a Document either you are the creator of the doc  or the PL and the Document  type shouldn't be = Restricted
                Boolean canEditDoc = (((d.CreatedById == UserInfo.getUserId()) ||(YTS_Utility.lookupRole('Program Leader'))) && (d.Document_Type__c=='Collaborative'))? true : false;

                String docId ;
                List<AllAttachments> attchList = new List<AllAttachments>();
                if(cdlMap.containsKey(d.Id)){
                    docId = cdlMap.get(d.Id);
                }else{
                    docId = '';
                }
                
                for(Attachment a: d.attachments){
                    isAttach = true;
                    attchList.add( 
                        new AllAttachments(
                            a.Id,
                            a.Name
                        )
                    );
                }

                if(String.isNotBlank(d.Sub_Category__c)) category = d.Category__c + ' - ' + d.Sub_Category__c;
                result.add(
                    new Document(
                        d.Id,
                        d.Name,
                        d.Document_Type__c,
                        category,
                        d.Sub_Category__c,
                        d.Description__c,
                        docId,
                        modifiedDate,
                        d.lastModifiedBy.Name,
                        createdDate,
                        d.createdBy.name,
                        badgeCSS,
                        canEditDoc,
                        Schema.sObjectType.ICY_Document__c.isUpdateable(),
                        Schema.sObjectType.ICY_Document__c.isDeletable(),
                        isAttach,
                        attchList.size() > 0?attchList:null
                    )
                );
            }
            retData.lstDocument = result;

        }
        return retData;
    }

    /**
     * retrieve related intakes
     */
    @AuraEnabled
    public static List<RelatedIntake> getRelatedIntakes(String recordId){
        List<RelatedIntake> result = new List<RelatedIntake>();
        //List<Intake__c> lstIntake = new List<Intake__c>();
        for(Intake__c intake : [SELECT Id, name, Status__c, Suggested_Service_Response__c from Intake__c WHERE Referral__c = :recordId ORDER BY CreatedDate desc]){
            RelatedIntake related = new RelatedIntake();
            related.recordId = intake.Id;
            related.name = intake.Name;
            related.intakeStatus = intake.Status__c;
            related.suggestedServiceResp = intake.Suggested_Service_Response__c;
            result.add(related);
        }
        return result;
    }

    /**
     * Retrieve Related Contacts
     */
    @AuraEnabled
    public static ParentwithContact getRelatedContacts(String recordId){
        Id parentRecordId = Id.valueOf(recordId);
        ParentwithContact retData = new ParentwithContact();
        List<RelatedContact> result = new List<RelatedContact>();
        List<Case_Contact__c> caseContacts = new List<Case_Contact__c>();
        if(parentRecordId.getSobjectType() == Schema.Referral__c.SObjectType) {
            caseContacts = [SELECT Id, Contact_Full_Name__c, Contact_Type__c, Contact_Subtype__c, Contact_Person_Profession_Role__c, Profession_Role__c,
                            Relationship_Subtype__c, Other_Relationship__c, Preferred_method_of_contact__c, Contact_Person_Email_Address__c,
                            Contact_Person_Home_Phone_Number__c, Contact_Person_Cell_Phone_Number__c, Contact_Person_Work_Phone_Number__c,
                            Contact_Person_Work_Phone_Extension__c, UserRecordAccess.HasEditAccess, UserRecordAccess.HasDeleteAccess,
                            CreatedDate, CreatedBy.Name, LastModifiedDate, LastModifiedBy.Name 
                            FROM Case_Contact__c WHERE Referral__c = :parentRecordId ORDER BY Contact_Type__c,CreatedDate desc];
            String parentStatus = [select Id, Status__c from Referral__c where id=:parentRecordId].Status__c;
            retData.isParentCompleted = parentStatus != 'Referral';
        }
        else if(parentRecordId.getSobjectType() == Schema.Case.SObjectType){
            caseContacts = [SELECT Id, Contact_Full_Name__c, Contact_Type__c, Contact_Subtype__c, Contact_Person_Profession_Role__c, Profession_Role__c,
                            Relationship_Subtype__c, Other_Relationship__c, Preferred_method_of_contact__c, Contact_Person_Email_Address__c,
                            Contact_Person_Home_Phone_Number__c, Contact_Person_Cell_Phone_Number__c, Contact_Person_Work_Phone_Number__c,
                            Contact_Person_Work_Phone_Extension__c, UserRecordAccess.HasEditAccess, UserRecordAccess.HasDeleteAccess,
                            CreatedDate, CreatedBy.Name, LastModifiedDate, LastModifiedBy.Name 
                            FROM Case_Contact__c WHERE Case__c = :parentRecordId ORDER BY Contact_Type__c,CreatedDate desc];
            String caseStatus = [SELECT ID, Status FROM Case WHERE ID = :parentRecordId].Status;
            retData.isParentCompleted = caseStatus == 'Closed';
        }
        else if(parentRecordId.getSobjectType() == Schema.Intake__c.SObjectType) {
            caseContacts = [SELECT Id, Contact_Full_Name__c, Contact_Type__c, Contact_Subtype__c, Contact_Person_Profession_Role__c, Profession_Role__c,
                            Relationship_Subtype__c, Other_Relationship__c, Preferred_method_of_contact__c, Contact_Person_Email_Address__c,
                            Contact_Person_Home_Phone_Number__c, Contact_Person_Cell_Phone_Number__c, Contact_Person_Work_Phone_Number__c,
                            Contact_Person_Work_Phone_Extension__c, UserRecordAccess.HasEditAccess, UserRecordAccess.HasDeleteAccess,
                            CreatedDate, CreatedBy.Name, LastModifiedDate, LastModifiedBy.Name 
                            FROM Case_Contact__c WHERE Intake__c = :parentRecordId ORDER BY Contact_Type__c,CreatedDate desc];
            String parentStatus = [select Id, Status__c from Intake__c where id=:parentRecordId].Status__c;
            retData.isParentCompleted = parentStatus == 'Complete' || parentStatus == 'Closed';
        }

        for(Case_Contact__c c: caseContacts){
            RelatedContact rc = new RelatedContact();
            rc.recordId = c.Id;
            rc.name = c.Contact_Full_Name__c;
            rc.contactType = c.Contact_Type__c;
            rc.contactSubType = c.Contact_Subtype__c;
            rc.role = (c.Profession_Role__c =='Other')? c.Contact_Person_Profession_Role__c:c.Profession_Role__c ;
            rc.relationship = (c.Relationship_Subtype__c == 'Other')?c.Other_Relationship__c:c.Relationship_Subtype__c;
            rc.preferredMethodOfContact = c.Preferred_method_of_contact__c;
            rc.email = c.Contact_Person_Email_Address__c;
            rc.cellPhone = c.Contact_Person_Cell_Phone_Number__c;
            if(String.isNotBlank(c.Contact_Person_Work_Phone_Number__c)){
                rc.workPhone = c.Contact_Person_Work_Phone_Number__c;
                if(String.isNotBlank(c.Contact_Person_Work_Phone_Extension__c))
                    rc.workPhone = rc.workPhone +' X '+c.Contact_Person_Work_Phone_Extension__c;
            }
            rc.createdOn = YTS_Utility.dateFormat_eeeeMMMdyyyy(c.CreatedDate);
            rc.lastModifiedOn = YTS_Utility.dateFormat_eeeeMMMdyyyy(c.LastModifiedDate);
            rc.createdBy = c.createdBy.Name;
            rc.lastModifiedBy = c.LastModifiedBy.Name;
            rc.hasDeleteAccess = Schema.sObjectType.Case_Contact__c.isDeletable();
            rc.hasEditAccess = Schema.sObjectType.Case_Contact__c.isUpdateable();
            rc.homePhone = c.Contact_Person_Home_Phone_Number__c;
            result.add(rc);
        }
        if(!result.isEmpty()){
            retData.lstContacts = result;
        }
        return retData;
    }


    /**
     * Upsert ICY_Note__c Record
     */
    @AuraEnabled
    public static String upsertNote(ICY_Notes__c note, String recordId, String noteId,String noteType){
        Id parentRecordId = Id.valueOf(recordId);
        if(String.isNotBlank(noteId)) note.Id = noteId;
        if(parentRecordId.getSobjectType() == Schema.Referral__c.SObjectType)
            note.Referral__c = parentRecordId;
        else if(parentRecordId.getSobjectType() == Schema.Case.SObjectType)
            note.Case__c = parentRecordId;
        else if(parentRecordId.getSobjectType() == Schema.Intake__c.SObjectType)
            note.Intake__c = parentRecordId;
        note.Name = String.isBlank(note.Referral_Subject__c)?noteType:note.Referral_Subject__c;
        note.Notes_Type__c = noteType;
        UPSERT note;
        return note.Id;
    }

    /**
     * Query note based on record Id
     */
    @AuraEnabled
    public static ICY_Notes__c getNote(String recordId){
        return [SELECT ID, Name, Description__c,ICY_Meeting_Date__c, Referral_Subject__c,Other__c,Notes_Type__c,Mode_Location__c,Other_Mode_Location__c,Team_Member__c,Other_Team_Member__c, Attendees__c, Length_of_Meeting__c FROM ICY_Notes__c WHERE Id=:recordId];
    }

    /**
     * Query ICY_Document__c based on record Id
     */
    @AuraEnabled
    public static ICY_Document__c getDocument(String recordId){
       return [SELECT Id, Name, Category__c, Sub_Category__c, Description__c, Document_Key_Words__c, CreatedDate, CreatedBy.Name, 
                LastModifiedDate, LastModifiedBy.Name, Other_Document_Type__c,Document_Type__c
                FROM ICY_Document__c WHERE ID=:recordId];
    }

    /**
     * Upsert ICY_Document__c record
     */
    @AuraEnabled
    public static ICY_Document__c upsertDocument(ICY_Document__c document, String recordId, String documentId, 
                                            String recordTypeDeveloperName, String contentDocumentId){
        Id parentRecordId = Id.valueOf(recordId);
        if(String.isNotBlank(documentId)) document.Id = documentId;
        if(parentRecordId.getSobjectType() == Schema.Referral__c.SObjectType)
            document.Referral__c = parentRecordId;
        else if(parentRecordId.getSobjectType() == Schema.Case.SObjectType)
            document.Case__c = parentRecordId;
        else if(parentRecordId.getSobjectType() == Schema.Intake__c.SObjectType)
            document.Intake__c = parentRecordId;
        
        document.Document_Type__c = recordTypeDeveloperName;

        UPSERT document;
        //Link content document to the case document Record
        if(String.isNotBlank(contentDocumentId)){
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.shareType = 'I';//Inferred Share
            cdl.visibility = 'AllUsers';//sharing with all users will allow ability to view the document when Case Document is changed from Restricted to Colloborative
            cdl.LinkedEntityId = document.Id;
            cdl.ContentDocumentId = contentDocumentId;
            INSERT cdl;
        }
        return document;
    }

    /**
     * Content Distribution For File Download
     */
    @AuraEnabled
    public static ContentDistribution getContentDistributionForFile(Id contentDocumentId){

        ContentVersion contentVersion = [ SELECT Id, ContentDocumentId, IsMajorVersion, IsLatest
                                          FROM ContentVersion 
                                          WHERE ContentDocumentId =: contentDocumentId
                                            AND IsLatest = true 
                                          LIMIT 1 ];

        List<ContentDistribution> contentDistribution = new List<ContentDistribution>([ SELECT Id, Name, ContentDownloadUrl, ContentVersionId 
                                                          FROM ContentDistribution 
                                                          WHERE ContentVersionId =: contentVersion.Id ]);
        if (!contentDistribution.isEmpty()) {
            return contentDistribution[0];
        }
        // else create new contentDistribution
        ContentDistribution newContentDistribution = new ContentDistribution( Name = 'contentDistribution',
                                                                              ContentVersionId = contentVersion.Id,
                                                                              PreferencesAllowViewInBrowser = true,
                                                                              PreferencesLinkLatestVersion = true,
                                                                              PreferencesNotifyOnVisit = false );
        insert newContentDistribution;

        return  [ SELECT Id, Name, ContentDownloadUrl, ContentDocumentId 
                  FROM ContentDistribution 
                  WHERE Id =: newContentDistribution.Id 
                  LIMIT 1 ];
    }


    /**
     * Get Current User Profile
     */
    @AuraEnabled
    public static String getUserProfileName(){
        Profile p = [SELECT Id, Name FROM PROFILE WHERE Id=:UserInfo.getProfileId()];
        return p.Name;
    }


    /**
     * Get Referred By Contact Details
     */
    @AuraEnabled
    public static YTS_Notes_Documents_Controller.RelatedContact getReferredByContact(String recordId){
        String referredById;
        Id parentRecordId = Id.valueOf(recordId);
        YTS_Notes_Documents_Controller.RelatedContact rc = new YTS_Notes_Documents_Controller.RelatedContact();

        if(parentRecordId.getSobjectType() == Schema.Referral__c.SObjectType) {
            
            Referral__c r = [SELECT Id, ICY_Referred_By__c FROM Referral__c WHERE ID=:parentRecordId];
            referredById = r.ICY_Referred_By__c;
        }
        else if(parentRecordId.getSobjectType() == Schema.Case.SObjectType){

            Case cs = [SELECT Id, (SELECT Id, ICY_Referred_By__c FROM Referrals__r) FROM Case WHERE Id=:parentRecordId];
            if(cs.Referrals__r.size() > 0){
                referredById = cs.Referrals__r[0].ICY_Referred_By__c;
            }
        }
        else if(parentRecordId.getSobjectType() == Schema.Intake__c.SObjectType) {
            Intake__c i = [SELECT Id, Referral__r.ICY_Referred_By__c FROM Intake__c WHERE ID=:parentRecordId];
            referredById = i.Referral__r.ICY_Referred_By__c;
        }

        if(String.isNotBlank(referredById)){
            
            Case_Contact__c c = [SELECT Id, Contact_Full_Name__c, Contact_Type__c, Contact_Subtype__c, Contact_Person_Profession_Role__c, Profession_Role__c,
                            Relationship_Subtype__c, Other_Relationship__c, Preferred_method_of_contact__c, Contact_Person_Email_Address__c,
                            Contact_Person_Home_Phone_Number__c, Contact_Person_Cell_Phone_Number__c, Contact_Person_Work_Phone_Number__c,
                            Contact_Person_Work_Phone_Extension__c, UserRecordAccess.HasEditAccess, UserRecordAccess.HasDeleteAccess,
                            CreatedDate, CreatedBy.Name, LastModifiedDate, LastModifiedBy.Name 
                            FROM Case_Contact__c WHERE ID =: referredById LIMIT 1];
            
            rc.recordId = c.Id;
            rc.name = c.Contact_Full_Name__c;
            rc.contactType = c.Contact_Type__c;
            rc.contactSubType = c.Contact_Subtype__c;
            rc.role = (c.Profession_Role__c =='Other')? c.Contact_Person_Profession_Role__c:c.Profession_Role__c ;
            rc.relationship = (c.Relationship_Subtype__c == 'Other')?c.Other_Relationship__c:c.Relationship_Subtype__c;
            rc.preferredMethodOfContact = c.Preferred_method_of_contact__c;
            rc.email = c.Contact_Person_Email_Address__c;
            rc.cellPhone = c.Contact_Person_Cell_Phone_Number__c;
            if(String.isNotBlank(c.Contact_Person_Work_Phone_Number__c)){
                rc.workPhone = c.Contact_Person_Work_Phone_Number__c;
                if(String.isNotBlank(c.Contact_Person_Work_Phone_Extension__c))
                    rc.workPhone = rc.workPhone +' X '+c.Contact_Person_Work_Phone_Extension__c;
            }
            rc.createdOn = YTS_Utility.dateFormat_eeeeMMMdyyyy(c.CreatedDate);
            rc.lastModifiedOn = YTS_Utility.dateFormat_eeeeMMMdyyyy(c.LastModifiedDate);
            rc.createdBy = c.createdBy.Name;
            rc.lastModifiedBy = c.LastModifiedBy.Name;
            rc.hasDeleteAccess = Schema.sObjectType.Case_Contact__c.isDeletable();
            rc.hasEditAccess = Schema.sObjectType.Case_Contact__c.isUpdateable();
            rc.homePhone = c.Contact_Person_Home_Phone_Number__c;

            return rc;

        }
        return null;
    }
    

    /**
     * Documents with parent status
     */
    public class ParentwithContact{
        @auraEnabled public Boolean isParentCompleted {get;set;}
        @auraenabled public List<RelatedContact> lstContacts  {get; set;}
    }
    /**
     * Case Contacts Wrapper
     */
    public class RelatedContact{
        @AuraEnabled public String recordId{get;set;}
        @AuraEnabled public String name{get;set;}
        @AuraEnabled public String contactType{get;set;}
        @AuraEnabled public String contactSubType{get;set;}
        @AuraEnabled public String role{get;set;}
        @AuraEnabled public String otherRoleDescription{get;set;}
        @AuraEnabled public String relationship{get;set;}
        @AuraEnabled public String preferredMethodOfContact{get;set;}
        @AuraEnabled public String email{get;set;}
        @AuraEnabled public String homePhone{get;set;}
        @AuraEnabled public String cellPhone{get;set;}
        @AuraEnabled public String workPhone{get;set;}
        @AuraEnabled public String createdOn{get;set;}
        @AuraEnabled public String createdBy{get;set;}
        @AuraEnabled public String lastModifiedOn{get;set;}
        @AuraEnabled public String lastModifiedBy{get;set;}
        @AuraEnabled public Boolean hasEditAccess{get;set;}
        @AuraEnabled public Boolean hasDeleteAccess{get;set;}
    }

    /**
     * Notes Wrapper
     */
    public Class Note{
        @AuraEnabled public String recordId{get;set;}
        @AuraEnabled public String name{get;set;}
        @AuraEnabled public String notesType{get;set;}
        @AuraEnabled public String subject{get;set;}
        @AuraEnabled public String description{get;set;}
        @AuraEnabled public Date meetingDate{get;set;}
        @AuraEnabled public String attendees{get;set;}
        @AuraEnabled public Decimal lengthOfMeeting{get;set;}
        @AuraEnabled public String createdOn{get;set;}
        @AuraEnabled public String createdBy{get;set;}
        @AuraEnabled public String lastModifiedOn{get;set;}
        @AuraEnabled public String lastModifiedBy{get;set;}
        @AuraEnabled public String badgeCSS{get;set;}
        @AuraEnabled public String teamMember{get;set;}
        @AuraEnabled public String modeLocation{get;set;}
        @AuraEnabled public String otherModeLocation{get;set;}
        @AuraEnabled public String noteSource{get;set;}
        @AuraEnabled public Boolean hasEditAccess{get;set;}
        @AuraEnabled public Boolean hasDeleteAccess{get;set;}
        @AuraEnabled public Boolean canEdit{get;set;}
        
        public Note(String recordId, String name, String notesType, String subject,
                        String description, Date meetingDate,String attendees, Decimal lengthOfMeeting, String lastModifiedOn, String lastModifiedBy,
                        String createdOn, String createdBy, String badgeCSS, String teamMember,String modeLocation,String othermodeLocation,String noteSource,Boolean hasEditAccess, Boolean hasDeleteAccess,Boolean canEdit){
            this.recordId = recordId;
            this.name = name;
            this.notesType = notesType;
            this.subject = subject;
            this.description = description;
            this.meetingDate= meetingDate;
            this.attendees = attendees;
            this.lengthOfMeeting = lengthOfMeeting;
            this.lastModifiedOn = lastModifiedOn;
            this.lastModifiedBy = lastModifiedBy;
            this.createdOn = createdOn;
            this.createdBy = createdBy;
            this.badgeCSS = badgeCSS;
            this.teamMember = teamMember;
            this.modeLocation = modeLocation;
            this.otherModeLocation = otherModeLocation;
            this.noteSource= noteSource;
            this.hasDeleteAccess = hasDeleteAccess;
            this.hasEditAccess = hasEditAccess;
            this.canEdit = canEdit;
        }
    }

    /**
     * Documents with parent status
     */
    public class ParentwithDocument{
        @auraEnabled public Boolean isParentCompleted {get;set;}
        @auraenabled public List<Document> lstDocument  {get; set;}
    }
    /**
     * Documents Wrapper Class
     */
    public Class Document{
        @AuraEnabled public String recordId{get;set;}
        @AuraEnabled public String name{get;set;}
        @AuraEnabled public String documentType{get;set;}
        @AuraEnabled public String category{get;set;}
        @AuraEnabled public String subCategory{get;set;}
        @AuraEnabled public String description{get;set;}
        @AuraEnabled public String documentId{get;set;}
        @AuraEnabled public String createdOn{get;set;}
        @AuraEnabled public String createdBy{get;set;}
        @AuraEnabled public String lastModifiedOn{get;set;}
        @AuraEnabled public String lastModifiedBy{get;set;}
        @AuraEnabled public String badgeCSS{get;set;}
        @AuraEnabled public Boolean canEditDoc{get;set;}
        @AuraEnabled public Boolean hasEditAccess{get;set;}
        @AuraEnabled public Boolean hasDeleteAccess{get;set;}
        @AuraEnabled public Boolean isAttachment{get;set;}
        @AuraEnabled public List<AllAttachments> attachmentsList{get;set;}

        public Document(String recordId, String name, String documentType, String category, 
                            String subCategory, String description, String documentId, String lastModifiedOn, 
                            String lastModifiedBy, String createdOn, String createdBy, String badgeCSS,Boolean canEditDoc,
                            Boolean hasEditAccess, Boolean hasDeleteAccess, Boolean isAttachment, List<AllAttachments> attachmentsList){
            this.recordId = recordId;
            this.name = name;
            this.category = category;
            this.subCategory = subCategory;
            this.description = description;
            this.documentId = documentId;
            this.lastModifiedOn = lastModifiedOn;
            this.lastModifiedBy = lastModifiedBy;
            this.createdOn = createdOn;
            this.createdBy = createdBy;
            this.documentType = documentType;
            this.badgeCSS = badgeCSS;
            this.canEditDoc = canEditDoc;
            this.hasDeleteAccess = hasDeleteAccess;
            this.hasEditAccess = hasEditAccess;
            this.isAttachment = isAttachment;
            this.attachmentsList = attachmentsList;
        }
    }

    /**
     * 
     */
    public class AllAttachments{
        @AuraEnabled public String recordId{get;set;}
        @AuraEnabled public String attachmentName{get;set;}
        public AllAttachments(String recordId, String attachmentName){
            this.recordId = recordId;
            this.attachmentName = attachmentName;
        }
    }

    /**
     * Related Intake records from Referral
     */
    public class RelatedIntake{
        @AuraEnabled public String recordId {get;set;}
        @AuraEnabled public String name {get;set;}
        @AuraEnabled public String intakeStatus {get;set;}
        @AuraEnabled public String suggestedServiceResp {get;set;}
    }
}