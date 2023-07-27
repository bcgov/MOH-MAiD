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

        List<Case> caseList = TestDataFactory.getCases();
        List<Case> existingCaseList1 = new List<Case>();
        List<Case> existingCaseList2 = new List<Case>();
        List<Case> existingCaseList3 = new List<Case>();
       	List<Case> existingCaseList4 = new List<Case>();

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
        
        existingCaseList4.add(TestDataFactory.getCasetoInsert());
        
       	GetCasePHNandVerify.getCasePHNandUpdate(existingCaseList4);
        test.stopTest();
    }

}