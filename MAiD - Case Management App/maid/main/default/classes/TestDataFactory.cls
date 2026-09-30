@isTest
/**
* @Name : TestDataFactory
* @Description: Creates shared pre-condition data for unit tests
* @ExpectedBehaviour: Creates and returs test data 
*/
public with sharing class TestDataFactory {
    

    /**
    * @Description : Uses getCases to create the case and returns the case list.      
    */
    public static List<Case> getCases(){

        List<Case> caseList = new List<Case>();
            Case cs  = new Case();
            
            cs.File_Creation_Date__c = System.today();
            cs.PHN__c = '0101012347';
            cs.Patient_Last_Name__c = 'Test';
            cs.Patient_First_Name__c = 'Test';
            cs.Patient_Date_of_Birth__c = date.valueOf('1980-01-01');
            cs.Gender__c = '1 - Male';
            cs.Type = 'MAiD Assessment of Eligibility'; 
            cs.Status = 'Awaiting Forms';
            cs.Date_of_MAiD__c = System.today();
            cs.Case_Type_Reported_Date__c = System.today();
            cs.recordtypeId = '0125W0000004KYUQA2';
        	cs.Prevent_save_on_duplicate_PHN__c = false;
            
        	insert cs;
        
            caseList.add(cs);
        	
        	Case cs1  = new Case();
            
            cs1.File_Creation_Date__c = System.today();
            cs1.PHN__c = '0101012346';
            cs1.Patient_Last_Name__c = 'Test';
            cs1.Patient_First_Name__c = 'Test';
            cs1.Patient_Date_of_Birth__c = date.valueOf('1980-01-01');
        	cs1.Prevent_save_on_duplicate_PHN__c = false;
            cs1.Gender__c = '1 - Male';
            cs1.Type = 'Discontinuation of Planning – Ineligible'; 
            cs1.Status = 'Awaiting Forms';
            cs1.Date_of_MAiD__c = System.today();
            cs1.Case_Type_Reported_Date__c = System.today();
            cs1.recordtypeId = '0125W0000004KYUQA2';
            
        	insert cs1;
        
        	Case cs2  = new Case();
            
            cs2.File_Creation_Date__c = System.today();
            cs2.PHN__c = '0101012348';
            cs2.Patient_Last_Name__c = 'Test';
            cs2.Patient_First_Name__c = 'Test';
            cs2.Patient_Date_of_Birth__c = date.valueOf('1980-01-01');
            cs2.Gender__c = '1 - Male';
            cs2.Type = 'Discontinuation of Planning: Withdrawn Request'; 
            cs2.Status = 'Awaiting Forms';
            cs2.Date_of_MAiD__c = System.today();
            cs2.Case_Type_Reported_Date__c = System.today();
            cs2.recordtypeId = '0125W0000004KYUQA2';
        	cs2.Prevent_save_on_duplicate_PHN__c = false;
            
        	insert cs2;
			

            List<Case> existingCaseList = [Select Id, PHN__c, Status, Type, RecordTypeId, Prevent_save_on_duplicate_PHN__c From Case];
            return existingCaseList;
    }
    
}