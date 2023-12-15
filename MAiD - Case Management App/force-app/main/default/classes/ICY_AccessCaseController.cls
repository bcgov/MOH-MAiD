public class ICY_AccessCaseController {

    @AuraEnabled
    public static List<ICY_MyCasesList> getAssignedCaseList(){
        Set<Id> caseIds = new Set<Id>();
        List<ICY_MyCasesList> result = new List<ICY_MyCasesList>();
        for(Case_Member__c cm: [SELECT Id, ICY_Case__c FROM Case_Member__c WHERE ICY_User__c=:UserInfo.getUserId() AND ICY_Status__c = 'Active' AND ICY_Case__c != null]){
            caseIds.add(cm.ICY_Case__c);
        }

        for(Case c: [SELECT Id, CaseNumber, Account.Name, Status, ICY_Geographic_Area__c, CreatedDate FROM CASE WHERE ID IN :caseIds]){
            ICY_MyCasesList caseDetails = new ICY_MyCasesList();
            caseDetails.caseId = c.Id;
            caseDetails.caseNumber = c.CaseNumber;
            caseDetails.individualName = c.Account.Name;
            caseDetails.caseStatus = c.Status;
            caseDetails.Location = c.ICY_Geographic_Area__c;
            caseDetails.dateTimeOpened = c.CreatedDate;
            result.add(caseDetails);
        }
        return result;
    }


    public Class ICY_MyCasesList{
        @AuraEnabled public String caseId{get;set;}
        @AuraEnabled public String caseNumber{get;set;}
        @AuraEnabled public String individualName{get;set;}
        @AuraEnabled public String caseStatus{get;set;}
        @AuraEnabled public String Location{get;set;}
        @AuraEnabled public Datetime dateTimeOpened{get;set;}
    }
}