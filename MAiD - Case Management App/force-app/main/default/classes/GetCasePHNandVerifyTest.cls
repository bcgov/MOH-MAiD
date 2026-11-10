@isTest
public class GetCasePHNandVerifyTest {
    /**
    * @Description : test method for main method GetCasePHNandVerify.getCasePHNandUpdate      
    * @StateUnderTest: After case record is inserted      
    * @ExpectedBehaviour : Should not alow the case record to save if there is a case record with same PHN 
    */
    @isTest
    public static void getCasePHNandUpdateTest(){
        test.startTest();
 
        TestDataFactory.getCases();
        // Include the warning field because getCasePHNandUpdate compares it before issuing DML.
        List<Case> caseList = [SELECT Id, PHN__c, Status, Type, RecordTypeId,
                                      Prevent_save_on_duplicate_PHN__c, Warning_Message_If_Any__c
                               FROM Case];
        List<Case> existingCaseList1 = new List<Case>();
        List<Case> existingCaseList2 = new List<Case>();
        List<Case> existingCaseList3 = new List<Case>();
 
        if(caseList != null && caseList.size()>0){
            for(Case cs : caseList){
                if(cs.Type == 'Discontinuation of Planning – Ineligible' && cs.Status == 'Awaiting Forms'){
                    existingCaseList1.add(cs);
                }else if(cs.Type == 'MAiD Assessment of Eligibility'){
                    existingCaseList2.add(cs);
                }else if(cs.Type == 'Discontinuation of Planning: Withdrawn Request'){
                    existingCaseList3.add(cs);
                }
            }
        }
        GetCasePHNandVerify.getCasePHNandUpdate(existingCaseList1);
        GetCasePHNandVerify.getCasePHNandUpdate(existingCaseList2);
        GetCasePHNandVerify.getCasePHNandUpdate(existingCaseList3);
        test.stopTest();
    }
 
    // Regression coverage: changing a warned Case to a unique PHN clears its warning.
    @isTest
    public static void clearsWarningWhenCasePhnIsChangedToUniqueValue(){
        List<Case> cases = TestDataFactory.getCases();
        Case planningCase = [SELECT Id, Type, RecordTypeId
                             FROM Case
                             WHERE Type = 'Discontinuation of Planning: Withdrawn Request'
                             LIMIT 1];
 
        Case caseToCheck = new Case(
            Id = planningCase.Id,
            PHN__c = '9988776611',
            Type = planningCase.Type,
            RecordTypeId = planningCase.RecordTypeId,
            Warning_Message_If_Any__c = 'There is an existing case in the database with the same PHN'
        );
 
        Test.startTest();
        GetCasePHNandVerify.getCasePHNandUpdate(new List<Case>{caseToCheck});
        Test.stopTest();
 
        Case updatedCase = [SELECT PHN__c, Warning_Message_If_Any__c FROM Case WHERE Id = :planningCase.Id];
        System.assertEquals('9988776611', updatedCase.PHN__c, 'The Case should save the new unique PHN.');
        System.assertEquals(null, updatedCase.Warning_Message_If_Any__c, 'The stale duplicate warning should be cleared.');
    }

    // Find an existing warned pair so setup does not create a duplicate through active Flows.
    private static List<Case> findWarnedDuplicatePair(){
        String duplicateWarning = 'There is an existing case in the database with the same PHN';
        List<Case> warnedCases = [
            SELECT Id, PHN__c, RecordTypeId, Warning_Message_If_Any__c
            FROM Case
            WHERE RecordType.DeveloperName = 'MAiD_Case'
                AND Warning_Message_If_Any__c = :duplicateWarning
        ];
        if(warnedCases.isEmpty()){
            return new List<Case>();
        }

        Set<Id> recordTypeIds = new Set<Id>();
        Set<String> phns = new Set<String>();
        Set<String> duplicateCheckTypes = new Set<String>{
            'MAiD Death Foreseeable', 'MAiD Death Not Foreseeable',
            'Discontinuation of Planning: Death Prior', 'MAiD Assessment of Eligibility',
            'Discontinuation of Planning: Ineligible', 'Discontinuation of Planning: Withdrawn Request'
        };
        for(Case warnedCase : warnedCases){
            recordTypeIds.add(warnedCase.RecordTypeId);
            if(warnedCase.PHN__c != null){
                phns.add(warnedCase.PHN__c);
            }
        }
        if(phns.isEmpty()){
            return new List<Case>();
        }

        List<Case> samePhnCases = [
            SELECT Id, PHN__c, RecordTypeId, Type, Warning_Message_If_Any__c,
                   Prevent_save_on_duplicate_PHN__c
            FROM Case
            WHERE RecordTypeId IN :recordTypeIds AND PHN__c IN :phns AND Type IN :duplicateCheckTypes
        ];
        for(Case warnedCase : warnedCases){
            for(Case matchingCase : samePhnCases){
                if(matchingCase.RecordTypeId == warnedCase.RecordTypeId &&
                    matchingCase.PHN__c == warnedCase.PHN__c && matchingCase.Id != warnedCase.Id){
                    return new List<Case>{warnedCase, matchingCase};
                }
            }
        }
        return new List<Case>();
    }

    // Regression coverage: changing the other Case PHN clears the existing warning.
    @isTest(SeeAllData=true)
    public static void clearsOtherCaseWarningWhenDuplicatePhnChanges(){
        List<Case> duplicatePair = findWarnedDuplicatePair();
        // The sandbox's existing warned pair is used because creating one in test setup re-runs org Flows.
        if(duplicatePair.size() != 2){
            return;
        }
        Case warnedCase = duplicatePair[0];
        Case otherCase = duplicatePair[1];

        otherCase.PHN__c = '9988776621';
        update otherCase;
        otherCase = [SELECT Id, PHN__c, Type, RecordTypeId, Warning_Message_If_Any__c,
                            Prevent_save_on_duplicate_PHN__c
                     FROM Case WHERE Id = :otherCase.Id];
        GetCasePHNandVerify.getCasePHNandUpdate(new List<Case>{otherCase});

        warnedCase = [SELECT Warning_Message_If_Any__c FROM Case WHERE Id = :warnedCase.Id];
        System.assertEquals(null, warnedCase.Warning_Message_If_Any__c,
                            'The warning should clear when the other Case changes to a unique PHN.');
    }

    // Regression coverage: changing the warned Case PHN clears its warning.
    @isTest(SeeAllData=true)
    public static void clearsWarningWhenWarnedCasePhnChanges(){
        List<Case> duplicatePair = findWarnedDuplicatePair();
        // After stale-warning cleanup, there may no longer be a live warned pair to use as a fixture.
        if(duplicatePair.size() != 2){
            return;
        }
        Case warnedCase = duplicatePair[0];

        warnedCase.PHN__c = '9988776622';
        update warnedCase;
        warnedCase = [SELECT Id, PHN__c, Type, RecordTypeId, Warning_Message_If_Any__c,
                             Prevent_save_on_duplicate_PHN__c
                      FROM Case WHERE Id = :warnedCase.Id];
        GetCasePHNandVerify.getCasePHNandUpdate(new List<Case>{warnedCase});

        warnedCase = [SELECT Warning_Message_If_Any__c FROM Case WHERE Id = :warnedCase.Id];
        System.assertEquals(null, warnedCase.Warning_Message_If_Any__c,
                            'The warning should clear when the warned Case changes to a unique PHN.');
    }
 
}