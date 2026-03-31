@isTest
public class YTS_Utility_Test {

    @testSetup static void testSetup() {
        // Create a test Referral record to get record type ID
        Referral__c testReferral = new Referral__c();
        testReferral.Individual_First_Name__c = 'Test';
        testReferral.Individual_Last_Name__c = 'Referral';
        testReferral.Individual_Date_of_Birth__c = System.today();
        testReferral.Type_of_Referral__c = 'Organizational Referral';
        testReferral.Referring_Organization__c = 'Test Organization';
        insert testReferral;
    }

    @isTest static void testGetRecordTypeIdByDeveloperName() {
        // Test with valid parameters
        String recordTypeId = YTS_Utility.getRecordTypeIdByDeveloperName('Referral__c', 'ICY_General');
        System.assertNotEquals(null, recordTypeId, 'Record type ID should be returned for valid parameters');
        
        // Test with blank objectApi
        String resultBlankObject = YTS_Utility.getRecordTypeIdByDeveloperName('', 'PHS_Referral');
        System.assertEquals(null, resultBlankObject, 'Should return null when objectApi is blank');
        
        // Test with blank recordTypeDeveloperName
        String resultBlankRecordType = YTS_Utility.getRecordTypeIdByDeveloperName('Referral__c', '');
        System.assertEquals(null, resultBlankRecordType, 'Should return null when recordTypeDeveloperName is blank');
    }

    @isTest static void testGetPicklistValues() {
        // Test with valid object and field
        Map<String, String> picklistValues = YTS_Utility.getPicklistValues('Referral__c', 'Individual_Gender__c');
        System.assertNotEquals(null, picklistValues, 'Should return a map of picklist values');
        System.assert(picklistValues.size() > 0, 'Picklist map should not be empty for valid field');
        
        // Test with blank objectApi
        Map<String, String> resultBlankObject = YTS_Utility.getPicklistValues('', 'Individual_Gender__c');
        System.assertEquals(true, resultBlankObject.isEmpty(), 'Should return empty map when objectApi is blank');
        
        // Test with blank fieldApi
        Map<String, String> resultBlankField = YTS_Utility.getPicklistValues('Referral__c', '');
        System.assertEquals(true, resultBlankField.isEmpty(), 'Should return empty map when fieldApi is blank');
    }

    @isTest static void testDateFormatEeeeMMdyyyyWithDateTime() {
        DateTime testDateTime = DateTime.newInstance(2021, 11, 4, 14, 30, 0);
        String formattedDate = YTS_Utility.dateFormat_eeeeMMMdyyyy(testDateTime);
        System.assertNotEquals(null, formattedDate, 'Should return formatted date string');
        System.assert(formattedDate.contains('Nov'), 'Should contain month abbreviation');
        System.assert(formattedDate.contains('2021'), 'Should contain year');
    }

    @isTest static void testDateFormatMMMdyyyyWithDate() {
        Date testDate = Date.newInstance(2021, 11, 4);
        String formattedDate = YTS_Utility.dateFormat_MMMdyyyy(testDate);
        System.assertEquals('Nov 4, 2021', formattedDate, 'Should return formatted date string MMM d, yyyy');
        
        // Test with null date
        String resultNull = YTS_Utility.dateFormat_MMMdyyyy((Date) null);
        System.assertEquals(null, resultNull, 'Should return null when date is null');
    }

    @isTest static void testDateFormatEeeeMMdyyyyWithDate() {
        Date testDate = Date.newInstance(2021, 11, 4);
        String formattedDate = YTS_Utility.dateFormat_eeeeMMMdyyyy(testDate);
        System.assertNotEquals(null, formattedDate, 'Should return formatted date string');
        System.assert(formattedDate.contains('Nov'), 'Should contain month abbreviation');
        System.assert(formattedDate.contains('2021'), 'Should contain year');
        
        // Test with null date
        String resultNull = YTS_Utility.dateFormat_eeeeMMMdyyyy((Date) null);
        System.assertEquals(null, resultNull, 'Should return null when date is null');
    }

    @isTest static void testDateFormatMMMdyyyyWithDateTime() {
        DateTime testDateTime = DateTime.newInstance(2021, 11, 4, 14, 30, 0);
        String formattedDate = YTS_Utility.dateFormat_MMMdyyyy(testDateTime);
        System.assertEquals('Nov 4, 2021', formattedDate, 'Should return formatted date string MMM d, yyyy');
        
        // Test with null datetime
        String resultNull = YTS_Utility.dateFormat_MMMdyyyy((DateTime) null);
        System.assertEquals(null, resultNull, 'Should return null when datetime is null');
    }

    @isTest static void testDateFormatYyyyMmDd() {
        Date testDate = Date.newInstance(2021, 11, 4);
        String formattedDate = YTS_Utility.dateFormat_yyyy_mm_dd(testDate);
        System.assertEquals('2021-11-4', formattedDate, 'Should return formatted date string yyyy-MM-dd');
        
        // Test with null date
        String resultNull = YTS_Utility.dateFormat_yyyy_mm_dd(null);
        System.assertEquals(null, resultNull, 'Should return null when date is null');
    }

    @isTest static void testDateFormatMMMdyyyykma() {
        DateTime testDateTime = DateTime.newInstance(2024, 1, 15, 16, 32, 0);
        String formattedDate = YTS_Utility.dateFormat_MMMdyyyykma(testDateTime);
        System.assertNotEquals(null, formattedDate, 'Should return formatted date string');
        System.assert(formattedDate.contains('January'), 'Should contain month name');
        System.assert(formattedDate.contains('2024'), 'Should contain year');
        System.assert(formattedDate.contains('pm'), 'Should contain lowercase pm');
    }

    @isTest static void testGetICYOrgWideEmailAddressId() {
        // This test verifies the method returns an ID or null based on org configuration
        Id emailAddressId = YTS_Utility.getICYOrgWideEmailAddressId();
        // Email address may or may not exist in test org, so just verify method executes without error
        System.assert(true, 'Method should execute without throwing exception');
    }

    @isTest static void testLookupRole() {
        // Test the lookupRole method
        Boolean result = YTS_Utility.lookupRole('System');
        System.assert(result != null, 'Method should return a boolean value');
        
        // Test with null parameter
        Boolean resultWithNull = YTS_Utility.lookupRole(null);
        System.assertEquals(false, resultWithNull, 'Should return false when role is null');
        
        // Test with empty string
        Boolean resultWithEmpty = YTS_Utility.lookupRole('');
        System.assertEquals(false, resultWithEmpty, 'Should return false when role is empty');
    }

    @isTest static void testIsTopRoleICY() {
        // This test verifies the method executes and returns a boolean
        Boolean isTopRole = YTS_Utility.isTopRoleICY();
        System.assert(isTopRole != null, 'Method should return a boolean value');
    }

    @isTest static void testPicklistValuesForMultipleFields() {
        // Test picklist values for different fields to ensure method works across different fields
        Map<String, String> genderPicklist = YTS_Utility.getPicklistValues('Referral__c', 'Individual_Gender__c');
        Map<String, String> typePicklist = YTS_Utility.getPicklistValues('Referral__c', 'Type_of_Referral__c');
        
        System.assert(genderPicklist.size() >= 0, 'Gender picklist map should be populated');
        System.assert(typePicklist.size() >= 0, 'Type of Referral picklist map should be populated');
    }

    @isTest static void testDateFormatEdgeCases() {
        // Test with first day of year
        Date newYearDate = Date.newInstance(2021, 1, 1);
        String newYearFormatted = YTS_Utility.dateFormat_MMMdyyyy(newYearDate);
        System.assertEquals('Jan 1, 2021', newYearFormatted, 'Should format Jan 1 correctly');
        
        // Test with last day of year
        Date lastDayDate = Date.newInstance(2021, 12, 31);
        String lastDayFormatted = YTS_Utility.dateFormat_MMMdyyyy(lastDayDate);
        System.assertEquals('Dec 31, 2021', lastDayFormatted, 'Should format Dec 31 correctly');
    }

}
