@isTest
private class ICYSelfRegistrationControllerTest {

    @testSetup
    static void setupData() {
        // Insert required Mapping_object__c record
        insert new Mapping_object__c(
            Functional_Domain_Type__c = 'PortalUserRegistration',
            Context_prompt__c = 'Test Prompt'
        );

        // Ensure RecordType 'ICY' exists for System_Access_Request__c
        // This step assumes you have a record type named 'ICY'
        // (If not, either create it in your org or adjust the test logic)
    }

    @isTest
    static void testConstructor() {
        Test.startTest();
        ICYSelfRegistrationController ctrl = new ICYSelfRegistrationController();
        System.assertNotEquals(null, ctrl.request);
        System.assertNotEquals(null, ctrl.mapobj);
        Test.stopTest();
    }

    @isTest
    static void testSubmitRequestSuccess() {
        PageReference pageRef = Page.IntegrateLogin;
        Test.setCurrentPage(pageRef);

        // Set mock URL parameters
        ApexPages.currentPage().getParameters().put('guid', 'ABC123');
        ApexPages.currentPage().getParameters().put('dname', 'John Doe');
        ApexPages.currentPage().getParameters().put('email', 'john@example.com');
        ApexPages.currentPage().getParameters().put('uname', 'johndoe');

        ICYSelfRegistrationController ctrl = new ICYSelfRegistrationController();
        ctrl.request.ICY_Employer_Organization__c = 'Government'; 
        ctrl.request.ICY_If_Other__c = null; 

        Test.startTest();
        PageReference result = ctrl.submitRequest();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('CommunitiesSelfRegConfirm'));
    }

    @isTest
    static void testSubmitRequestFailsForOtherWithoutValue() {
        PageReference pageRef = Page.IntegrateLogin;
        Test.setCurrentPage(pageRef);

        ApexPages.currentPage().getParameters().put('guid', 'XYZ123');
        ApexPages.currentPage().getParameters().put('dname', 'Jane Doe');
        ApexPages.currentPage().getParameters().put('email', 'jane@example.com');
        ApexPages.currentPage().getParameters().put('uname', 'janedoe');

        ICYSelfRegistrationController ctrl = new ICYSelfRegistrationController();
        ctrl.request.ICY_Employer_Organization__c = 'Other';
        ctrl.request.ICY_If_Other__c = ''; 

        Test.startTest();
        PageReference result = ctrl.submitRequest();
        Test.stopTest();

        System.assertEquals(null, result);
        System.assertEquals(1, ApexPages.getMessages().size());
    }
}
