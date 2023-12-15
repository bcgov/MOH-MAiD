@isTest
public class ICY_BatchToSendInactiveCaseNotesTest {
	static testMethod void unitTest(){
        Case obj = new Case();
        obj.Status= 'Open';
        obj.Location__c = 'Quesnel';
        obj.Region__c = 'Northern Region';
        obj.Last_Active_Date__c = Date.today().addDays(-1);
        obj.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('ICY_Standard_Case').getRecordTypeId();
        insert obj;
        Test.startTest();
        Database.executeBatch(new ICY_BatchToSendInactiveCaseNotes());
        Test.stopTest();
        ICY_BatchToSendInactiveCaseNotes scheudleClass = new ICY_BatchToSendInactiveCaseNotes ();
        String sch = '0 0 * * * ?';
        System.schedule('ICY_BatchToSendInactiveCaseNotes',  '0 41 * * * ?',scheudleClass);
    }
}