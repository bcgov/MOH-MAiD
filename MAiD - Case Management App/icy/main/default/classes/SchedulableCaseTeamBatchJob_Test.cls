@isTest
public class SchedulableCaseTeamBatchJob_Test { 
	static testMethod void myUnitTest()
	{
        test.starttest();
        SchedulableCaseTeamBatchJob objTest = new SchedulableCaseTeamBatchJob();
        String chron = '0 0 23 * * ?';        
        system.schedule('Test Sched', chron, objTest);
        test.stopTest();
    }
}