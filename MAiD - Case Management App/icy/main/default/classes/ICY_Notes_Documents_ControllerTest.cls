@isTest
public class ICY_Notes_Documents_ControllerTest {
    @isTest
    static void testNoteWrapper() {
        // Create Note instance using constructor
        YTS_Notes_Documents_Controller.Note note = new YTS_Notes_Documents_Controller.Note(
            '001xx000003DGX1AAO',     // recordId
            'Sample Note',            // name
            'Client Note',            // notesType
            'Follow-up',              // subject
            'Discussed next steps',   // description
            '2025-05-08',             // lastModifiedOn
            'John Doe',               // lastModifiedBy
            '2025-05-01',             // createdOn
            'Jane Smith',             // createdBy
            'badge-blue',             // badgeCSS
            true,                     // hasEditAccess
            false                     // hasDeleteAccess
        );

        // Optional assertions to ensure fields are populated correctly
        System.assertEquals('Sample Note', note.name);
        System.assertEquals('Follow-up', note.subject);
        System.assertEquals(true, note.hasEditAccess);
        System.assertEquals(false, note.hasDeleteAccess);
    }
    @isTest
    static void testDocumentWrapper() {
        // Create a list of attachments
        List<YTS_Notes_Documents_Controller.AllAttachments> attachmentList = new List<YTS_Notes_Documents_Controller.AllAttachments>();
        attachmentList.add(new YTS_Notes_Documents_Controller.AllAttachments('001xx000003DGX1AAO', 'SampleAttachment.pdf'));

        // Create Document instance
        YTS_Notes_Documents_Controller.Document doc = new YTS_Notes_Documents_Controller.Document(
            '001xx000003DGX1AAO',
            'SampleDoc',
            'Case File',
            'Legal',
            'Initial Review',
            'This is a test document',
            '069xx0000001FjKAAU',
            '2025-05-08',
            'Test Modifier',
            '2025-05-07',
            'Test Creator',
            'badge-green',
            true,
            true,
            true,
            attachmentList
        );

        // Optional assertions to validate field population
        System.assertEquals('SampleDoc', doc.name);
        System.assertEquals(true, doc.hasEditAccess);
        System.assertEquals(1, doc.attachmentsList.size());
    }
    
    static testMethod void unitTest(){
        Referral__c obj = new Referral__c();
        obj.RecordTypeId = YTS_Utility.getRecordTypeIdByDeveloperName('Referral__c', 'ICY_General');
        insert obj;

        ICY_Notes__c notes = new ICY_Notes__c();
        notes.Name = 'Test';
        notes.Notes_Type__c = 'Restricted';
        notes.Referral__c = obj.Id;
        notes.Referral_Subject__c = 'Other';
        insert notes;

        Intake__c intake = new Intake__c();
        intake.Referral__c = obj.Id;
        insert intake;

        ICY_Document__c doc = new ICY_Document__c();
        doc.Referral__c = obj.Id;
        doc.Document_Type__c  = 'Restricted';
        insert doc;

        Case_Contact__c objCaseCon = new Case_Contact__c();
        objCaseCon.Intake__c = intake.id;
        insert objCaseCon;

        update new Referral__c(Id=obj.Id,ICY_Referred_By__c = objCaseCon.id);

        Blob bodyBlob=Blob.valueOf('Unit Test ContentVersion Body');
        ContentVersion contentVersion_1 = new ContentVersion(
            Title='Header_Picture1',
            PathOnClient ='/Header_Picture1.jpg',
            VersionData = bodyBlob,
            origin = 'H'
        );
        insert contentVersion_1;

        case objCase = new case ();
        objCase.status = 'New';
        objCase.Origin = 'Phone';
        objCase.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('ICY_Standard_Case').getRecordTypeId();
        objCase.Referral__c = obj.Id;
        insert objCase;

        ContentVersion contentVersion_2 = [SELECT Id, Title, ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion_1.Id LIMIT 1];

        ICY_Notes_Documents_Controller.getRelatedNotes(obj.Id, true, 'Other',false);
        ICY_Notes_Documents_Controller.getRelatedNotes(intake.Id, true, 'Other',false);
        ICY_Notes_Documents_Controller.getRelatedNotes(objCase.Id, true, 'Other',false);
         ICY_Notes_Documents_Controller.getRelatedNotes(objCase.Id, false, 'Other',true);
        ICY_Notes_Documents_Controller.getRelatedDocuments(obj.Id);
        ICY_Notes_Documents_Controller.getRelatedDocuments(objCase.Id);
        ICY_Notes_Documents_Controller.getRelatedDocuments(intake.Id);
        ICY_Notes_Documents_Controller.getRelatedIntakes(obj.Id);
        ICY_Notes_Documents_Controller.upsertNote(notes, obj.Id, notes.Id, '');
        ICY_Notes_Documents_Controller.getNote(notes.Id);
        ICY_Notes_Documents_Controller.getDocument(doc.Id);
        ICY_Notes_Documents_Controller.upsertDocument(doc,obj.Id, doc.Id, 'Restricted', contentVersion_2.ContentDocumentId);
        ICY_Notes_Documents_Controller.getUserProfileName();
        ICY_Notes_Documents_Controller.getContentDistributionForFile(contentVersion_2.ContentDocumentId);
        YTS_Notes_Documents_Controller.getContentDistributionForFile(contentVersion_2.ContentDocumentId);
        YTS_Notes_Documents_Controller.getRelatedIntakes(obj.Id);
        ICY_Notes_Documents_Controller.getRelatedContacts(obj.Id);
        ICY_Notes_Documents_Controller.getRelatedContacts(intake.Id);
        ICY_Notes_Documents_Controller.getRelatedContacts(objCase.Id);

        ICY_Notes_Documents_Controller.getReferredByContact(obj.Id);
        ICY_Notes_Documents_Controller.getReferredByContact(intake.Id);
        ICY_Notes_Documents_Controller.getReferredByContact(objCase.Id);
    }
}