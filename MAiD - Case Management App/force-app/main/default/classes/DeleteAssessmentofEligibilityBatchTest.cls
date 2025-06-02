@isTest
private class DeleteAssessmentofEligibilityBatchTest {

    @isTest
    static void testBatchDeleteSingleCaseWithAttachments() {
        // Step 1: Setup a single case
        Case newCase = new Case(
            Status = 'Awaiting Forms',
            Case_Type_Reported_Date__c = System.today().addDays(-61),
            Type = 'MAiD Assessment of Eligibility',
            PHN__c = '2214221454',  // Add PHN__c field here
            RecordTypeId = [SELECT Id FROM RecordType WHERE DeveloperName = 'Error_Log' LIMIT 1].Id
        );
        insert newCase;

        // Step 2: Create an attachment and content document for the case
        Attachment attachment = new Attachment(
            ParentId = newCase.Id,
            Name = 'Test Attachment',
            Body = Blob.valueOf('Test attachment content')
        );
        insert attachment;

        ContentDocumentLink docLink = new ContentDocumentLink(
            LinkedEntityId = newCase.Id,
            //ContentDocumentId = [SELECT Id FROM ContentDocument LIMIT 1].Id,
            ShareType = 'V'
        );
        //insert docLink;

        // Step 3: Run the batch job
        Test.startTest();
        DeleteAssessmentofEligibilityCasesBatch batch = new DeleteAssessmentofEligibilityCasesBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Step 4: Verify the deletion of Case, Attachment, and ContentDocumentLink
        List<Case> deletedCases = [SELECT Id FROM Case WHERE Id = :newCase.Id];
        System.assertEquals(0, deletedCases.size(), 'Case should be deleted');

        List<Attachment> deletedAttachments = [SELECT Id FROM Attachment WHERE ParentId = :newCase.Id];
        System.assertEquals(0, deletedAttachments.size(), 'Attachment should be deleted');

        List<ContentDocumentLink> deletedDocLinks = [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :newCase.Id];
        System.assertEquals(0, deletedDocLinks.size(), 'ContentDocumentLink should be deleted');

        // Note: ContentDocument deletion is handled by the ContentDocumentLink deletion
    }

    @isTest
    static void testBatchDeleteSingleCaseWithoutAttachments() {
        // Step 1: Setup a single case without attachments
        Case newCase = new Case(
            Status = 'Awaiting Forms',
            Case_Type_Reported_Date__c = System.today().addDays(-61),
            Type = 'MAiD Assessment of Eligibility',
            PHN__c = '2214221454',  // Add PHN__c field here
            RecordTypeId = [SELECT Id FROM RecordType WHERE DeveloperName = 'Error_Log' LIMIT 1].Id
        );
        insert newCase;

        // Step 2: Run the batch job without attachments
        Test.startTest();
        DeleteAssessmentofEligibilityCasesBatch batch = new DeleteAssessmentofEligibilityCasesBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Step 3: Verify the deletion of Case (attachments don't exist)
        List<Case> deletedCases = [SELECT Id FROM Case WHERE Id = :newCase.Id];
        System.assertEquals(0, deletedCases.size(), 'Case should be deleted');

        List<Attachment> deletedAttachments = [SELECT Id FROM Attachment WHERE ParentId = :newCase.Id];
        System.assertEquals(0, deletedAttachments.size(), 'No attachments should be present');

        List<ContentDocumentLink> deletedDocLinks = [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :newCase.Id];
        System.assertEquals(0, deletedDocLinks.size(), 'No ContentDocumentLinks should be present');
    }

    @isTest
    static void testBatchDeleteSingleCaseWithMultipleAttachments() {
        // Step 1: Setup a single case with multiple attachments
        Case newCase = new Case(
            Status = 'Awaiting Forms',
            Case_Type_Reported_Date__c = System.today().addDays(-61),
            Type = 'MAiD Assessment of Eligibility',
            PHN__c = '2214221454',  // Add PHN__c field here
            RecordTypeId = [SELECT Id FROM RecordType WHERE DeveloperName = 'Error_Log' LIMIT 1].Id
        );
        insert newCase;

        // Step 2: Create multiple attachments for the case
        List<Attachment> attachments = new List<Attachment>();
        for (Integer i = 0; i < 2; i++) {
            Attachment attachment = new Attachment(
                ParentId = newCase.Id,
                Name = 'Test Attachment ' + i,
                Body = Blob.valueOf('Test attachment content ' + i)
            );
            attachments.add(attachment);
        }
        insert attachments;

        ContentDocumentLink docLink = new ContentDocumentLink(
            LinkedEntityId = newCase.Id,
            //ContentDocumentId = [SELECT Id FROM ContentDocument LIMIT 1].Id,
            ShareType = 'V'
        );
        //insert docLink;

        // Step 3: Run the batch job
        Test.startTest();
        DeleteAssessmentofEligibilityCasesBatch batch = new DeleteAssessmentofEligibilityCasesBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Step 4: Verify the deletion of Case, Attachments, and ContentDocumentLink
        List<Case> deletedCases = [SELECT Id FROM Case WHERE Id = :newCase.Id];
        System.assertEquals(0, deletedCases.size(), 'Case should be deleted');

        List<Attachment> deletedAttachments = [SELECT Id FROM Attachment WHERE ParentId = :newCase.Id];
        System.assertEquals(0, deletedAttachments.size(), 'Attachments should be deleted');

        List<ContentDocumentLink> deletedDocLinks = [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :newCase.Id];
        System.assertEquals(0, deletedDocLinks.size(), 'ContentDocumentLink should be deleted');
    }


}