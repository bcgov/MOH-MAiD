@isTest
public class ICY_BatchToSendInactiveCaseNotesTest {
	static testMethod void unitTest(){
        
     Referral__c RefRecord = new Referral__c();
     RefRecord.Type_of_Referral__c = 'Organizational Referral';
     RefRecord.Referring_Organization__c = 'Health Authority';
     RefRecord.Individual_First_Name__c = 'Test';
     RefRecord.Individual_Middle_Name__c = 'Middle';
     RefRecord.Individual_Last_Name__c = 'Referral';
     RefRecord.Individual_Preferred_Name__c = 'Ref';
     RefRecord.Individual_Date_of_Birth__c = System.today();
     RefRecord.Individual_Gender__c = 'Male';
     RefRecord.Individual_Pronouns__c = 'He';
     RefRecord.EIS_Region__c = 'Northern Region';
     RefRecord.EIS_Location__c = 'Peace North';
     RefRecord.Mailing_Address_same_as_Physical_Address__c = true;
     RefRecord.Physical_Address_Line_1__c = 'Test';
     RefRecord.Physical_Address_Postal_Code__c = 'M1J 2J1';
     RefRecord.Physical_Address_Province__c = 'BC';
     RefRecord.Physical_Address_City__c = 'Vancouver';
     RefRecord.Mailing_Address_Line_1__c = 'Test';
     RefRecord.Mailing_Address_City__c = 'Vancouver';
     RefRecord.Mailing_Address_Postal_Code__c = 'M1J 2J1';
     RefRecord.Mailing_Address_Province__c = 'BC';
     RefRecord.Preferred_method_of_contact__c = 'Phone';
     RefRecord.Individual_Home_Phone_Number__c = '2223334444';
     RefRecord.Individual_Cell_Phone_Number__c = '3334445555';
     RefRecord.Individual_Email_Address__c = '';
     RefRecord.Language_in_the_Home__c = 'Mandarin';
     RefRecord.Other_Language__c = 'Hindi';
     RefRecord.Primary_Contact_Is_Individual_Indicator__c = false;
     RefRecord.Is_Individual_Attending_School__c = 'Yes';
     RefRecord.Current_School__c = 'Test School';
     RefRecord.Who_does_the_youth_live_with__c = 'Family';
     RefRecord.Is_stable_housing_a_concern__c = '';
     RefRecord.Explain_housing_concern__c = 'Test Test';
     RefRecord.Special_limitations_hearing_sight_mob__c = 'Test';
     RefRecord.What_services_they_are_waiting_for__c = 'Test Services';
     RefRecord.DAA_or_other_cultural_or_spiritual_repre__c = 'Test';
     RefRecord.Referral_Notes__c = 'This is a test note.';
     insert RefRecord;
        Case obj = new Case();
        obj.Status= 'Open';
        obj.Location__c = 'Quesnel';
        obj.Region__c = 'Northern Region';
        obj.Last_Active_Date__c = Date.today().addDays(-1);
        obj.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('ICY_Standard_Case').getRecordTypeId();
        obj.referral__c= RefRecord.Id;
        insert obj;
        Test.startTest();
        Database.executeBatch(new ICY_BatchToSendInactiveCaseNotes());
        Test.stopTest();
        ICY_BatchToSendInactiveCaseNotes scheudleClass = new ICY_BatchToSendInactiveCaseNotes ();
        String sch = '0 0 * * * ?';
        System.schedule('ICY_BatchToSendInactiveCaseNotes',  '0 41 * * * ?',scheudleClass);
    }
}