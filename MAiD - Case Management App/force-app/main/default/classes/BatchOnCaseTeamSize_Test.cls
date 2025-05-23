@isTest
public class BatchOnCaseTeamSize_Test {
	@testSetup static void testSetup(){
		
        ICY_ReferralFeatureUtilityTest.setup();
		
      }
	  static testMethod void myUnitTest()
	{	BatchOnCaseTeamSize objTest = new BatchOnCaseTeamSize();
		Database.executebatch(objTest);
         List<Case> relatedCases = new List<Case>();





	}

}