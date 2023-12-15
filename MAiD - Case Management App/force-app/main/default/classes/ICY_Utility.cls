public with sharing class ICY_Utility {
    public ICY_Utility() {

    }


    @AuraEnabled(cacheable=true)
    public static List<sObject> fetchLookupData(String searchKey, String sObjectApiName){
        List < sObject > returnList = new List < sObject > ();
        string sWildCardText = '%' + searchKey + '%';
        string sQuery;
        if(sObjectApiName == 'Case_Contact__c'){
            sQuery = 'Select Id,Contact_Person_First_Name__c,Contact_Person_Last_Name__c  From ' + sObjectApiName + ' Where Name Like : sWildCardText order by createdDate DESC LIMIT 15';
        }else{
            sQuery = 'Select Id,Name From ' + sObjectApiName + ' Where Name Like : sWildCardText order by createdDate DESC LIMIT 5';
        }
        for (sObject obj: database.query(sQuery)) {
            returnList.add(obj);
        }
        return returnList;
    }

    // Method to fetch lookup default value
    @AuraEnabled
    public static sObject fetchDefaultRecord(string recordId , string sObjectApiName) {
        string sRecId = recordId;
        string sQuery = 'Select Id,Name From ' + sObjectApiName + ' Where Id = : sRecId LIMIT 1';
        if(sObjectApiName == 'Case_Contact__c'){
            sQuery = 'Select Id,Contact_Person_First_Name__c,Contact_Person_Last_Name__c  From ' + sObjectApiName + ' Where Id = : sRecId LIMIT 1';
        }
        for (sObject obj: database.query(sQuery)) {
            return obj;
        }
        return null;
    }

    public static List<Case> filterICYCases(List<Case> cs) {
        Id CaseRecordTypeIdCloseCase = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('ICY_Close_Case').getRecordTypeId();
        Id CaseRecordTypeIdStandardCase = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('ICY_Standard_Case').getRecordTypeId();

        List<Case> ICYCase = new List<Case>();
        for (Case c : cs) {
            if ((c.RecordTypeId == CaseRecordTypeIdCloseCase) ||(c.RecordTypeId == CaseRecordTypeIdStandardCase)) {
              ICYCase.add(c);
            }
        }
        return ICYCase;
    }
}