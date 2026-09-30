public with sharing class NewsAnnouncements_controller {

    public Login_Page_Messages__c mapobj {get; set;}
    
    public NewsAnnouncements_controller() {
        
        mapobj = [select id,System_Announcements__c, Recent_News__c, Display_Announcements__c, Display_Recent_News__c from Login_Page_Messages__c LIMIT 1];
        //mapobj = [select id,System_Announcements__c from Login_Page_Messages__c LIMIT 1];
        
    }
    

public pagereference dosave()
  {
     upsert mapobj;
     pagereference page=new pagereference('/apex/NewsAnnouncements_page');
     return page;
  }       
}