@isTest
public class ICY_Notes_Documents_ControllerTest {
    static testMethod void unitTest(){
        Referral__c obj = new Referral__c();
        obj.RecordTypeId = YTS_Utility.getRecordTypeIdByDeveloperName('Referral__c', 'ICY_General');
        obj.ICY_Program_Leader__c=ICY_Referral_Controller.getICYPlId('Coast Mountains Team Hazelton');
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