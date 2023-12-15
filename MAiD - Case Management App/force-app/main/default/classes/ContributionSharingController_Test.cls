@isTest
private class ContributionSharingController_Test {

    static testMethod void myUnitTest() {

    //system.runAs(usr){
        Case cas = new case();
        cas.Status = 'New';
        //cas.OwnerId = usr.id;
        cas.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('ICY_Standard_Case').getRecordTypeId();
        insert cas;


        Referral__c ref = new Referral__c();
        //ref.OwnerId = usr.id;
        ref.Status__c = 'Case Created';
        ref.Individual_First_Name__c ='Test';
        ref.Individual_Last_Name__c ='User';
        ref.Individual_Date_of_Birth__c = system.today();
        ref.Individual_Home_Phone_Number__c = '1231231';
        ref.Individual_Email_Address__c = 'test@test.com';
        ref.Physical_Address_City__c='City';
        ref.Physical_Address_Line_1__c ='12th street';
        ref.Physical_Address_Postal_Code__c='A1A1A1';
        insert ref;

    Contribution__c cascon = new Contribution__c();
        cascon.Action__c = 'Edit';
        cascon.Contribution_Type__c= 'Case Alert';
        cascon.Individual_Name__c = 'Test User';
        cascon.Case__c = cas.Id;
        insert cascon;
        test.starttest();

      pagereference pageref = Page.ContributionSharingPage;
      test.setCurrentPageReference(pageref);
      ApexPages.currentPage().getParameters().put('id',cas.id);
        Apexpages.standardcontroller sc = new Apexpages.standardcontroller(cas);
        ContributionSharingController obj = new ContributionSharingController (sc);
        system.assertNotEquals(cas.id, null);
        test.stoptest();
    }
}