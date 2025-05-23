@isTest
public with sharing class ICYRegistrationLoginControllerTest {
        @testSetup
        static void setupData() {
            Login_Page_Messages__c msg = new Login_Page_Messages__c(
                Identifier__c = 'ICY',
                System_Announcements__c = 'System Message',
                Display_Announcements__c = true,
                Recent_News__c = 'Recent News',
                Display_Recent_News__c = true
            );
            insert msg;
        }
     
       
    
        @isTest
        static void testConstructorAndFlags() {
            Test.startTest();
            ICYRegistrationLoginController ctrl = new ICYRegistrationLoginController();
            System.assertNotEquals(null, ctrl.mapobj);
            System.assertEquals(true, ctrl.dispAnnouncements);
            System.assertEquals(true, ctrl.dispNews);
            Test.stopTest();
        }
    
        @isTest
        static void testAddCookiesWithId() {
            Test.startTest();
    
            String contactId = '003000000000001';
            PageReference pageRef = Page.IntegrateLogin; 
            Test.setCurrentPage(pageRef);
            ApexPages.currentPage().getParameters().put('id', contactId);
    
            ICYRegistrationLoginController ctrl = new ICYRegistrationLoginController();
            PageReference result = ctrl.addcookies();
    
            System.assertNotEquals(null, result);
            System.assert(result.getUrl().contains('https://sfs.gov.bc.ca/affwebservices/public/saml2sso'));
    
            Test.stopTest();
        }
    
        @isTest
        static void testAddCookiesWithoutId() {
            Test.startTest();
            PageReference pageRef = Page.IntegrateLogin;
            Test.setCurrentPage(pageRef);
    
            ICYRegistrationLoginController ctrl = new ICYRegistrationLoginController();
            PageReference result = ctrl.forwardToAuthPage();
    
            System.assertNotEquals(null, result);
            Test.stopTest();
        }
}

