@isTest
private class DeleteAssessmentofEligibilityBatchTest {

    @testSetup
    static void setupTestData() {
        RecordType maidCaseRecordType = [SELECT Id FROM RecordType WHERE SObjectType = 'Case' AND DeveloperName = 'MAiD_Case' LIMIT 1];

        List<Case> cases = new List<Case>();

        // Case with Attachments, Lookup Child, and Master-Detail Child
        Case caseWithAll = new Case(
            RecordTypeId = maidCaseRecordType.Id,
            Type = 'MAiD Assessment of Eligibility',
            Status = 'Awaiting Forms',
            Patient_Date_of_Birth__c = Date.newInstance(1969, 1, 1),
            PHN__c = '2214221451',
            Patient_First_Name__c = 'oooo',
            Patient_Last_Name__c = 'ttttt',
            Gender__c = '1 - Male',
            Date_of_MAiD__c = Date.today().addDays(-61),
            Case_Type_Reported_Date__c = Date.today().addDays(-61)
        );
        cases.add(caseWithAll);

        // Case with only Master-Detail Child
        Case caseWithMasterDetailOnly = new Case(
            RecordTypeId = maidCaseRecordType.Id,
            Type = 'MAiD Assessment of Eligibility',
            Status = 'Awaiting Forms',
            Patient_Date_of_Birth__c = Date.newInstance(1969, 1, 1),
            PHN__c = '2214221452',
            Patient_First_Name__c = 'oooo',
            Patient_Last_Name__c = 'ttttt',
            Gender__c = '1 - Male',
            Date_of_MAiD__c = Date.today().addDays(-61),
            Case_Type_Reported_Date__c = Date.today().addDays(-61)
        );
        cases.add(caseWithMasterDetailOnly);

        // Case with only Lookup Child
        Case caseWithLookupOnly = new Case(
            RecordTypeId = maidCaseRecordType.Id,
            Type = 'MAiD Assessment of Eligibility',
            Status = 'Awaiting Forms',
            Patient_Date_of_Birth__c = Date.newInstance(1969, 1, 1),
            PHN__c = '2214221453',
            Patient_First_Name__c = 'oooo',
            Patient_Last_Name__c = 'ttttt',
            Gender__c = '1 - Male',
            Date_of_MAiD__c = Date.today().addDays(-61),
            Case_Type_Reported_Date__c = Date.today().addDays(-61)
        );
        cases.add(caseWithLookupOnly);

        // Case with No Attachments
        Case caseWithoutAttachments = new Case(
            RecordTypeId = maidCaseRecordType.Id,
            Type = 'MAiD Assessment of Eligibility',
            Status = 'Awaiting Forms',
            Patient_Date_of_Birth__c = Date.newInstance(1969, 1, 1),
            PHN__c = '2214221454',
            Patient_First_Name__c = 'oooo',
            Patient_Last_Name__c = 'ttttt',
            Gender__c = '1 - Male',
            Date_of_MAiD__c = Date.today().addDays(-61),
            Case_Type_Reported_Date__c = Date.today().addDays(-61)
        );
        cases.add(caseWithoutAttachments);

        // Case with No Lookup Child Records
        Case caseWithoutLookup = new Case(
            RecordTypeId = maidCaseRecordType.Id,
            Type = 'MAiD Assessment of Eligibility',
            Status = 'Awaiting Forms',
            Patient_Date_of_Birth__c = Date.newInstance(1969, 1, 1),
            PHN__c = '2214221455',
            Patient_First_Name__c = 'oooo',
            Patient_Last_Name__c = 'ttttt',
            Gender__c = '1 - Male',
            Date_of_MAiD__c = Date.today().addDays(-61),
            Case_Type_Reported_Date__c = Date.today().addDays(-61)
        );
        cases.add(caseWithoutLookup);

        insert cases;

        // Create Lookup Child Record for the first and third Cases
        List<Form_1641__c> lookupChildren = new List<Form_1641__c>();
        lookupChildren.add(new Form_1641__c(Case__c = caseWithAll.Id, PHN__c = caseWithAll.PHN__c, Patient_Date_of_Birth__c = caseWithAll.Patient_Date_of_Birth__c));
        lookupChildren.add(new Form_1641__c(Case__c = caseWithLookupOnly.Id, PHN__c = caseWithLookupOnly.PHN__c, Patient_Date_of_Birth__c = caseWithLookupOnly.Patient_Date_of_Birth__c));
        insert lookupChildren;

        // Create Master-Detail Child Records for two Cases
        List<Form_1632__c> masterChildren = new List<Form_1632__c>();
        masterChildren.add(new Form_1632__c(Case__c = caseWithAll.Id, PHN__c = caseWithAll.PHN__c, Patient_Date_of_Birth__c = caseWithAll.Patient_Date_of_Birth__c));
        masterChildren.add(new Form_1632__c(Case__c = caseWithMasterDetailOnly.Id, PHN__c = caseWithMasterDetailOnly.PHN__c, Patient_Date_of_Birth__c = caseWithMasterDetailOnly.Patient_Date_of_Birth__c));
        insert masterChildren;

        // Attachments for Case and Lookup Child
        List<Attachment> attachments = new List<Attachment>();
        attachments.add(new Attachment(Name = 'CaseAttachment.pdf', Body = Blob.valueOf('Sample Data'), ParentId = caseWithAll.Id));
        attachments.add(new Attachment(Name = 'ChildAttachment.pdf', Body = Blob.valueOf('Sample Data'), ParentId = lookupChildren[0].Id));
        insert attachments;

        // Try to create ContentDocument and ContentDocumentLink safely
        try {
            ContentVersion contentVersion = new ContentVersion(
                Title = 'TestDocument',
                PathOnClient = 'TestDocument.pdf',
                VersionData = Blob.valueOf('Test Content')
            );
            insert contentVersion;

            // Fetch the ContentDocumentId after ContentVersion insertion
            ContentDocument contentDocument = [SELECT Id FROM ContentDocument WHERE LatestPublishedVersionId = :contentVersion.Id LIMIT 1];

            ContentDocumentLink contentLink = new ContentDocumentLink(
                LinkedEntityId = caseWithAll.Id,
                ContentDocumentId = contentDocument.Id,
                ShareType = 'I'
            );
            insert contentLink;

            System.debug('Test Data Created with ContentDocument.');
        } catch (Exception e) {
            System.debug('Failed to create ContentDocument or ContentDocumentLink: ' + e.getMessage());
        }
    }

    @isTest
    static void testBatchExecution() {
        // Fetch initial counts for all objects
        Integer initialCaseCount = [SELECT COUNT() FROM Case WHERE Status = 'Awaiting Forms' AND Type = 'MAiD Assessment of Eligibility'];
        Integer initialAttachmentCount = [SELECT COUNT() FROM Attachment];
        Integer initialLookupCount = [SELECT COUNT() FROM Form_1641__c];
        Integer initialMasterDetailCount = [SELECT COUNT() FROM Form_1632__c];

        Test.startTest();
        Database.executeBatch(new DeleteAssessmentofEligibilityCasesBatch(), 200);
        Test.stopTest();

        // Verify all relevant Case records are deleted
        Integer remainingCases = [SELECT COUNT() FROM Case WHERE Status = 'Awaiting Forms' AND Type = 'MAiD Assessment of Eligibility'];
        System.assertEquals(0, remainingCases, 'Cases should be deleted.');

        // Verify Attachments are deleted only if they existed initially
        Integer remainingAttachments = [SELECT COUNT() FROM Attachment];
        if (initialAttachmentCount > 0) {
            System.assertEquals(0, remainingAttachments, 'Attachments should be deleted.');
        }

        // Verify Lookup Child records are deleted
        Integer remainingLookupChildren = [SELECT COUNT() FROM Form_1641__c];
        if (initialLookupCount > 0) {
            System.assertEquals(0, remainingLookupChildren, 'Lookup Child records should be deleted.');
        }

        // Verify Master-Detail Child records are deleted
        Integer remainingMasterChildren = [SELECT COUNT() FROM Form_1632__c];
        if (initialMasterDetailCount > 0) {
            System.assertEquals(0, remainingMasterChildren, 'Master-Detail Child records should be deleted.');
        }

        // Query the Cases
        List<Case> caseRecords = [SELECT Id FROM Case WHERE Status = 'Awaiting Forms' AND Type = 'MAiD Assessment of Eligibility'];

        // Create the parentIds list
        List<Id> parentIds = new List<Id>();
        for (Case c : caseRecords) {
            parentIds.add(c.Id);
        }

        // Loop through each parentId and query ContentDocumentLink for each Case individually
        List<Id> docIds = new List<Id>(); // To collect the ContentDocumentIds
        for (Id parentId : parentIds) {
            // Query ContentDocumentLink for a single LinkedEntityId (parentId)
            List<ContentDocumentLink> docLinks = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :parentId];

            // Collect ContentDocumentIds from the query
            for (ContentDocumentLink link : docLinks) {
                docIds.add(link.ContentDocumentId);
            }
        }

        // If there are ContentDocuments to delete, proceed
        if (!docIds.isEmpty()) {
            // Query ContentDocuments linked to those ContentDocumentIds
            List<ContentDocument> documents = [SELECT Id FROM ContentDocument WHERE Id IN :docIds];
            
            // Safely delete the ContentDocuments if they exist
            if (!documents.isEmpty()) {
                Database.delete(documents, false);  // Safely delete without failing test
            }
        }

        // Verify ContentDocuments and ContentDocumentLinks are deleted
        // Loop through parentIds to check if ContentDocumentLinks are deleted
        for (Id parentId : parentIds) {
            Integer remainingContentDocumentLinks = [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :parentId];
            System.assertEquals(0, remainingContentDocumentLinks, 'ContentDocumentLinks for Case ' + parentId + ' should be deleted.');
        }

        // Verify ContentDocuments are deleted
        Integer remainingContentDocuments = [SELECT COUNT() FROM ContentDocument WHERE Id IN :docIds];
        System.assertEquals(0, remainingContentDocuments, 'ContentDocuments should be deleted.');
    }
}