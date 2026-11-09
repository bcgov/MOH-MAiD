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
 
}