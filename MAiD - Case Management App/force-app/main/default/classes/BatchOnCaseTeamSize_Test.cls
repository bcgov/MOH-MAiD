@isTest
public class BatchOnCaseTeamSize_Test {
	static testMethod void myUnitTest()
	{
		Case cas = new case();
        cas.Status = 'New';
        cas.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('ICY_Standard_Case').getRecordTypeId();
        insert cas;
		BatchOnCaseTeamSize objTest = new BatchOnCaseTeamSize();
		Database.executebatch(objTest);
         List<Case> relatedCases = new List<Case>();





	}

}