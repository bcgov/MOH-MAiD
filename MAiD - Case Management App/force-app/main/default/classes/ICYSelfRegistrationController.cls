/**
* An apex page controller that supports self registration of users in communities that allow self registration
*/
public without sharing class ICYSelfRegistrationController {

    public System_Access_Request__c request {get; set;}
    public Mapping_object__c mapobj{get; set;}

    public ICYSelfRegistrationController() {
        request = new System_Access_Request__c();

        mapobj = [select id,Functional_Domain_Type__c,Context_prompt__c from Mapping_object__c where Functional_Domain_Type__c = 'PortalUserRegistration'
                  LIMIT 1];
    }

    public PageReference submitRequest() {

        request.RecordTypeId = Schema.SObjectType.System_Access_Request__c.getRecordTypeInfosByName().get('ICY').getRecordTypeId();
        request.SiteMinder_GUID__c = ApexPages.currentPage().getParameters().get('guid');
        request.BCeIDorIDIR_DisplayName__c = ApexPages.currentPage().getParameters().get('dname');
        request.BCeIDorIDIR_Email__c = ApexPages.currentPage().getParameters().get('email');
        request.BCeIDorIDIR_UserName__c = ApexPages.currentPage().getParameters().get('uname');

        string role = request.ICY_Employer_Organization__c;
        if(role == 'Other' && (string.isBlank(request.ICY_If_Other__c)))
        {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Please specify the other Organization'));
            return null;
        }else
        {
            insert request;
            if (request.Id != null) {
                PageReference page = System.Page.CommunitiesSelfRegConfirm;
                page.setRedirect(true);
                return page;
            }
            return null;
        }
    }
}