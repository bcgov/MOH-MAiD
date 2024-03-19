public with sharing class ICY_CustomSettingsController {

    // Method to retrieve hierarchy custom setting values
    @AuraEnabled(cacheable=true)
    public static ICY_Outage_Message_Settings__c getHierarchyCustomSetting() {
        // Retrieve the hierarchy custom setting values for the current user's profile
        return ICY_Outage_Message_Settings__c.getOrgDefaults();
    }
}
