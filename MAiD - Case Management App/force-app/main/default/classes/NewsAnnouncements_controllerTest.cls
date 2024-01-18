@isTest
public class NewsAnnouncements_controllerTest {
 static testmethod void testsave() {

 Login_Page_Messages__c lpm = new Login_Page_Messages__c();
            lpm.Identifier__c = '123';
            lpm.System_Announcements__c = 'Test TrialTest TrialTest TrialTest TrialTest TrialTest Trial';
            lpm.Recent_News__c = 'Test TrialTest TrialTest TrialTest TrialTest TrialTest Trial';
            lpm.Display_Announcements__c=True;
            lpm.Display_Recent_News__c=True;
            insert lpm;

    NewsAnnouncements_controller controller = new NewsAnnouncements_controller();

       controller.dosave();
      }
}