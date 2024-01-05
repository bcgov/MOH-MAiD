@istest
class ClearDraftReferralSchedulerTest{
    public static testMethod void testschedule() {
        Test.StartTest();
        ClearDraftReferralScheduler testsche = new ClearDraftReferralScheduler();
        String sch = '0 0 23 * * ?';
        system.schedule('Test status Check', sch, testsche );
        Test.stopTest();
    }
}