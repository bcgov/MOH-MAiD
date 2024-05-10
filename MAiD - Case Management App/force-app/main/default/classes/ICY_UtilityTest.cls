@istest
public class ICY_UtilityTest {
	@testSetup static void testSetup(){
        
        //Profile p = [SELECT Id FROM Profile WHERE Name='STADD Navigator']; 
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        User Usr = new User(Alias = 'standt', Email='standarduser@gov.bc.ca', 
        EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', 
        LocaleSidKey='en_US', ProfileId = p.Id, 
        TimeZoneSidKey='America/Los_Angeles', UserName='standarduser@gov.bc.ca'); 
        insert Usr;
        
        Referral__c ref = new Referral__c();   
        ref.OwnerId = Usr.id;  
        ref.Status__c = 'Case Created';
        ref.Mailing_Address_same_as_Physical_Address__c = true;
        ref.Individual_First_Name__c ='Test';
        ref.Individual_Last_Name__c ='User';
        ref.Individual_Date_of_Birth__c = system.today();
        ref.Individual_Home_Phone_Number__c = '1231231111';
        ref.Physical_Address_City__c='City';
        ref.Physical_Address_Line_1__c ='12th street';
        ref.Physical_Address_Postal_Code__c='V2X6M2';
        ref.Mailing_Address_Postal_Code__c='V1V1V1';
        ref.Eligibility_Type__c = 'DD';
        ref.Community__c = 'MAPLE RIDGE';
        ref.ICY_Program_Leader__c=ICY_Referral_Controller.getICYPlId('Coast Mountains Team Hazelton');
        insert ref;
        
        Case_Contact__c refCon = new Case_Contact__c();
        refCon.Referral__c = ref.id;
        refCon.Relationship_Subtype__c = 'test';
        insert refCon;
    }
    
    @isTest static void testFetchLookupData(){
        Referral__c ref= [Select id, Name from Referral__c];
        Case_Contact__c refCon = [Select id, Name from Case_Contact__c];
        ICY_Utility.fetchLookupData(refCon.name, 'Case_Contact__c');
        ICY_Utility.fetchLookupData(ref.name, 'Referral__c');
	}
    
    @isTest static void testFetchDefaultRecord(){
        Referral__c ref= [Select id, Name from Referral__c];
        Case_Contact__c refCon = [Select id, Name from Case_Contact__c];
        ICY_Utility.fetchDefaultRecord(refCon.Id, 'Case_Contact__c');
        ICY_Utility.fetchDefaultRecord(ref.id, 'Referral__c');
	}
}