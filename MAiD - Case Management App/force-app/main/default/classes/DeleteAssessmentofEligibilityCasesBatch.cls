/**********************************************************************************************
* @Author:      Ranadheer Reddy Gundla 
* @Date:        31 March 2025
* @Description: The class is used for deleting the MAiD Assesment of Eligibility Cases which are created for morethan 60days and the Status is in Awaiting Forms.
* @Revision(s): [Date] - [Change Reference] - [Changed By] - [Description]  
***********************************************************************************************/
global class DeleteAssessmentofEligibilityCasesBatch implements Database.Batchable<SObject>, Database.Stateful, Schedulable {

    global Database.QueryLocator start(Database.BatchableContext BC) {
        System.debug('Starting batch job...');

        return Database.getQueryLocator([
            SELECT Id FROM Case 
            WHERE Status = 'Awaiting Forms' 
            AND Case_Type_Reported_Date__c < LAST_N_DAYS:60 
            AND Type = 'MAiD Assessment of Eligibility'
        ]);
    }

    global void execute(Database.BatchableContext BC, List<Case> cases) {
        System.debug('Executing batch process, number of cases found: ' + cases.size());

        Set<Id> caseIds = new Set<Id>();
        for (Case c : cases) {
            caseIds.add(c.Id);
        }

        if (!caseIds.isEmpty()) {
            System.debug('Case IDs to process: ' + caseIds);

            // Step 1: Identify Error_Log child Cases
            List<Case> errorLogCases = [SELECT Id FROM Case WHERE ParentId IN :caseIds AND RecordType.DeveloperName = 'Error_Log'];
            Set<Id> errorLogCaseIds = new Set<Id>();
            for (Case elCase : errorLogCases) {
                errorLogCaseIds.add(elCase.Id);
            }

            if (!errorLogCaseIds.isEmpty()) {
                System.debug('Found Error_Log child Cases, deleting attachments and ContentDocuments...');
                deleteAttachmentsAndDocuments(errorLogCaseIds);

                System.debug('Deleting Error_Log child Cases...');
                safeDeleteRecords(errorLogCases);
            }

            // Step 2: Identify Master-Detail Child Records
            List<SObject> masterDetailChildren = new List<SObject>();
            masterDetailChildren.addAll([SELECT Id FROM Form_1632__c WHERE Case__c IN :caseIds]);
            masterDetailChildren.addAll([SELECT Id FROM Form_1634__c WHERE Case__c IN :caseIds]);
            masterDetailChildren.addAll([SELECT Id FROM Form_1635__c WHERE Case__c IN :caseIds]);
            masterDetailChildren.addAll([SELECT Id FROM Form_1645__c WHERE Case__c IN :caseIds]);
            masterDetailChildren.addAll([SELECT Id FROM Form_RXMAR__c WHERE Case__c IN :caseIds]);

            System.debug('Master-Detail Child Records fetched: ' + masterDetailChildren.size());

            // Step 3: Delete attachments for Master-Detail child records first
            // Extract IDs for Master-Detail child records
			Set<Id> masterDetailChildIds = new Set<Id>();  
				for (SObject rec : masterDetailChildren) {  
                    masterDetailChildIds.add((Id) rec.get('Id'));  
                        }

            // Delete attachments for Master-Detail child records
                if (!masterDetailChildIds.isEmpty()) {
        			deleteAttachmentsAndDocuments(masterDetailChildIds);
                    }

            // Step 4: Delete Master-Detail child records
            System.debug('Deleting Master-Detail Child records...');
            safeDeleteRecords(masterDetailChildren);

            // Step 5: Identify Lookup Child Records
            List<SObject> lookupChildren = new List<SObject>();
            lookupChildren.addAll([SELECT Id FROM Form_1633__c WHERE Case__c IN :caseIds]);
            lookupChildren.addAll([SELECT Id FROM Form_1641__c WHERE Case__c IN :caseIds]);
            lookupChildren.addAll([SELECT Id FROM Form_1642__c WHERE Case__c IN :caseIds]);

            System.debug('Lookup Child Records fetched: ' + lookupChildren.size());

            // Step 6: Delete attachments for lookup child records first
            // Extract IDs for Lookup child records
			Set<Id> lookupChildIds = new Set<Id>();  
			for (SObject rec : lookupChildren) {  
        		lookupChildIds.add((Id) rec.get('Id'));  
				}

			// Delete attachments for Lookup child records
			if (!lookupChildIds.isEmpty()) {
                deleteAttachmentsAndDocuments(lookupChildIds);
				}

            // Step 7: Delete lookup child records
            System.debug('Deleting Lookup Child records...');
            safeDeleteRecords(lookupChildren);

            // Step 8: Delete attachments & ContentDocuments for Cases
            System.debug('Deleting attachments and ContentDocuments for Cases...');
            deleteAttachmentsAndDocuments(caseIds);

            // Step 9: Delete the Case records
            System.debug('Deleting Cases...');
            safeDeleteRecords(cases);
        }
    }

    /**
     * Helper method to delete records safely using try-catch
     */
    private void safeDeleteRecords(List<SObject> records) {
        if (records.isEmpty()) {
            return;
        }
        try {
            Database.delete(records, false);
        } catch (DmlException e) {
            for (Integer i = 0; i < e.getNumDml(); i++) {
                System.debug('Error deleting record: ' + e.getDmlMessage(i));
            }
        }
    }

    /**
     * Helper method to delete Attachments & ContentDocuments
     */
    private void deleteAttachmentsAndDocuments(Set<Id> parentIds) {
        if (parentIds.isEmpty()) {
            System.debug('No parent records to process for deletion.');
            return;
        }

        System.debug('Deleting Attachments and ContentDocuments for Parent IDs: ' + parentIds);

        try {
            // Delete Attachments
            List<Attachment> attachments = [SELECT Id FROM Attachment WHERE ParentId IN :parentIds];
            if (!attachments.isEmpty()) {
                System.debug('Deleting ' + attachments.size() + ' attachments...');
                Database.delete(attachments, false);
            }
        } catch (DmlException e) {
            for (Integer i = 0; i < e.getNumDml(); i++) {
                System.debug('Error deleting attachment: ' + e.getDmlMessage(i));
            }
        }

        try {
            // Delete ContentDocumentLinks
            List<ContentDocumentLink> docLinks = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId IN :parentIds];
            if (!docLinks.isEmpty()) {
                List<Id> docIds = new List<Id>();
                for (ContentDocumentLink link : docLinks) {
                    docIds.add(link.ContentDocumentId);
                }

                // Delete ContentDocuments
                List<ContentDocument> documents = [SELECT Id FROM ContentDocument WHERE Id IN :docIds];
                if (!documents.isEmpty()) {
                    System.debug('Deleting ' + documents.size() + ' ContentDocuments...');
                    Database.delete(documents, false);
                }
            }
        } catch (DmlException e) {
            for (Integer i = 0; i < e.getNumDml(); i++) {
                System.debug('Error deleting content document: ' + e.getDmlMessage(i));
            }
        }
    }

    global void finish(Database.BatchableContext BC) {
        System.debug('Batch job completed successfully.');
    }

    global void execute(SchedulableContext SC) {
        System.debug('Scheduled batch job is executing.');
        Database.executeBatch(new DeleteAssessmentofEligibilityCasesBatch(), 200);
    }
}