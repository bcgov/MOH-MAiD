@isTest
public class ICY_SystemAccessRequestEmailTrigger_Test {
    static testMethod void test_Trigger(){
     System.runAs ( new User(Id = UserInfo.getUserId()) ) {
         contact c = new contact();
         c.LastName='test';
         c.Email='test@test.com';
         insert c;

         System_Access_Request__c record = new System_Access_Request__c();
         record.First_Name__c = 'A';
         record.Last_Name__c = 'B';
         record.Email__c = 'test@test.com';
         record.Contact_Phone_Number__c = '2222222';
         record.ICY_Access_requested__c = 'Admin';
         record.ICY_Employer_Organization__c = 'Other';
         record.ICY_Community_Assigned__c = 'Pacific Rim';
         record.ICY_If_Other__c = 'test';
         record.Business_BCeID_IDIR__c = 'test';
         insert record;
         Assert.areEqual(2, Limits.getEmailInvocations());
        }

    }
}