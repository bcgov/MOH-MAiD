/**
 * An apex page controller that exposes the site login functionality
 */
global without sharing class ICYRegistrationLoginController {

 //global ICYREgistrationLoginController () {}
    
    //Rena's code for SSO
    public string StandardRedirectUrl = 'https://sfs.gov.bc.ca/affwebservices/public/saml2sso?SPID=stadd_prod1_sfdcspid';

        public PageReference addcookies(){
        string contactID ='';
        string url = ApexPages.currentPage().getURL();
        integer ind = url.indexof('?id=');
        if (ind!=-1){
            contactID = url.substring(ind+4);
        }
        cookie StaddID = new Cookie('StaddID', contactID, null,-1,false);
        ApexPages.currentPage().setCookies(new Cookie[]{StaddID});
        if(ind!=-1){
            PageReference pr = new PageReference(StandardRedirectUrl);
            pr.setRedirect(true);
            return pr;
        }
        return null;
    }
    //Rena's code ends here
    
    public Login_Page_Messages__c mapobj {get; set;}
    public Boolean dispAnnouncements {get;set;}
    public Boolean dispNews {get;set;}
    //Reshma updated to add Recent News and System announcments section on login page
    global ICYREgistrationLoginController () {
    
    mapobj = [SELECT id,System_Announcements__c, Display_Announcements__c,Recent_News__c, Display_Recent_News__c from Login_Page_Messages__c WHERE Identifier__c='ICY'];
   
    if (mapobj.System_Announcements__c != '' && mapobj.System_Announcements__c != null &&  mapobj.Display_Announcements__c == true ){
        dispAnnouncements = true;
        system.debug('Reshmacheckingdispannouncements:'+dispAnnouncements);
    }
    else {
        dispAnnouncements = false;
    }
    if(mapobj.Recent_News__c != '' && mapobj.Recent_News__c != null &&  mapobj.Display_Recent_News__c == true ){
        dispNews = true;
        system.debug('Reshmacheckingdispnew:'+dispNews);
    }
    else {
        dispNews = false;
    } 

    }
    //Reshma's code ends here
  
    
    // Code we will invoke on page load.
    global PageReference forwardToAuthPage() {
        String startUrl = System.currentPageReference().getParameters().get('startURL');
        String displayType = System.currentPageReference().getParameters().get('display');
        return Network.forwardToAuthPage(startUrl, displayType);
    }
}