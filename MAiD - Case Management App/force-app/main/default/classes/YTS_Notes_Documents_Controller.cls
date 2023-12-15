/**
 *
 */
public with sharing class YTS_Notes_Documents_Controller {
    public YTS_Notes_Documents_Controller() {

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
                            CreatedDate, CreatedBy.Name, LastModifiedDate, LastModifiedBy.Name,Inactive__c
                            FROM Case_Contact__c WHERE Referral__c = :parentRecordId ORDER BY Inactive__c,Contact_Type__c,CreatedDate desc];
            String parentStatus = [select Id, Status__c from Referral__c where id=:parentRecordId].Status__c;
            retData.isParentCompleted = parentStatus != 'Referral';
        }
        else if(parentRecordId.getSobjectType() == Schema.Case.SObjectType){
            caseContacts = [SELECT Id, Contact_Full_Name__c, Contact_Type__c, Contact_Subtype__c, Contact_Person_Profession_Role__c, Profession_Role__c,
                            Relationship_Subtype__c, Other_Relationship__c, Preferred_method_of_contact__c, Contact_Person_Email_Address__c,
                            Contact_Person_Home_Phone_Number__c, Contact_Person_Cell_Phone_Number__c, Contact_Person_Work_Phone_Number__c,
                            Contact_Person_Work_Phone_Extension__c, UserRecordAccess.HasEditAccess, UserRecordAccess.HasDeleteAccess,
                            CreatedDate, CreatedBy.Name, LastModifiedDate, LastModifiedBy.Name,Inactive__c
                            FROM Case_Contact__c WHERE Case__c = :parentRecordId ORDER BY Inactive__c,Contact_Type__c,CreatedDate desc];
            String caseStatus = [SELECT ID, Status FROM Case WHERE ID = :parentRecordId].Status;
            retData.isParentCompleted = caseStatus == 'Closed';
        }
        else if(parentRecordId.getSobjectType() == Schema.Intake__c.SObjectType) {
            caseContacts = [SELECT Id, Contact_Full_Name__c, Contact_Type__c, Contact_Subtype__c, Contact_Person_Profession_Role__c, Profession_Role__c,
                            Relationship_Subtype__c, Other_Relationship__c, Preferred_method_of_contact__c, Contact_Person_Email_Address__c,
                            Contact_Person_Home_Phone_Number__c, Contact_Person_Cell_Phone_Number__c, Contact_Person_Work_Phone_Number__c,
                            Contact_Person_Work_Phone_Extension__c, UserRecordAccess.HasEditAccess, UserRecordAccess.HasDeleteAccess,
                            CreatedDate, CreatedBy.Name, LastModifiedDate, LastModifiedBy.Name,Inactive__c
                            FROM Case_Contact__c WHERE Intake__c = :parentRecordId ORDER BY Inactive__c,Contact_Type__c,CreatedDate desc];
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
            rc.isActive = (c.Inactive__c)? false:true ;
            result.add(rc);
        }
        if(!result.isEmpty()){
            retData.lstContacts = result;
        }
        return retData;
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
        @AuraEnabled public Boolean isActive{get;set;}
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
        @AuraEnabled public String createdOn{get;set;}
        @AuraEnabled public String createdBy{get;set;}
        @AuraEnabled public String lastModifiedOn{get;set;}
        @AuraEnabled public String lastModifiedBy{get;set;}
        @AuraEnabled public String badgeCSS{get;set;}
        @AuraEnabled public Boolean hasEditAccess{get;set;}
        @AuraEnabled public Boolean hasDeleteAccess{get;set;}

        public Note(String recordId, String name, String notesType, String subject,
                        String description, String lastModifiedOn, String lastModifiedBy,
                        String createdOn, String createdBy, String badgeCSS, Boolean hasEditAccess, Boolean hasDeleteAccess){
            this.recordId = recordId;
            this.name = name;
            this.notesType = notesType;
            this.subject = subject;
            this.description = description;
            this.lastModifiedOn = lastModifiedOn;
            this.lastModifiedBy = lastModifiedBy;
            this.createdOn = createdOn;
            this.createdBy = createdBy;
            this.badgeCSS = badgeCSS;
            this.hasDeleteAccess = hasDeleteAccess;
            this.hasEditAccess = hasEditAccess;
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
        @AuraEnabled public Boolean hasEditAccess{get;set;}
        @AuraEnabled public Boolean hasDeleteAccess{get;set;}
        @AuraEnabled public Boolean isAttachment{get;set;}
        @AuraEnabled public List<AllAttachments> attachmentsList{get;set;}

        public Document(String recordId, String name, String documentType, String category,
                            String subCategory, String description, String documentId, String lastModifiedOn,
                            String lastModifiedBy, String createdOn, String createdBy, String badgeCSS,
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