global class ICY_BatchToSendInactiveCaseNotes implements Database.Batchable<sObject>,Schedulable {
    String query;
    Integer daysToCountInactiveNotes = Integer.valueof(Label.ICY_DaysForInactiveNotes);
    global static Id orgwideemailId = YTS_Utility.getICYOrgWideEmailAddressId();
    
    global void execute(SchedulableContext sc){
        ICY_BatchToSendInactiveCaseNotes b = new ICY_BatchToSendInactiveCaseNotes(); //ur batch class
      database.executebatch(b);
    }
    public Database.QueryLocator start(Database.BatchableContext BC) {
      String query = 'select id,ownerId,CaseNumber from case where Last_Active_Date__c >=Last_N_Days:'+daysToCountInactiveNotes;
      return Database.getQueryLocator(query);
    }
  
    public void execute(Database.BatchableContext BC, 
                        List<Case> scope) {
       List<Messaging.SingleEmailMessage> emailMsgLst = new List<Messaging.SingleEmailMessage>();
       for(Case obj:scope){
           Messaging.SingleEmailMessage Emailmessage = new Messaging.SingleEmailMessage();
           Emailmessage.subject='Case Inactive';
           Emailmessage.whatId = obj.ownerId;
           Emailmessage.targetObjectId = obj.ownerId; 
           String Message = 'Hello, <br/><br/>';
           Message += 'This is a notification that case ('+'<a href="'+URL.getSalesforceBaseUrl().toExternalForm()+'/'+obj.id+'">'+obj.CaseNumber+'</a>) appears to have been inactive for over 90 days. Please follow link for more information.';
            
           Emailmessage.setHtmlBody(Message);
           Emailmessage.saveAsActivity = false;
           if(orgwideEmailId != null) Emailmessage.setOrgWideEmailAddressId(orgwideEmailId);
           emailMsgLst.add(Emailmessage);
       }
       if(!emailMsgLst.isEmpty()){
           Messaging.sendEmail(emailMsgLst);
       }
    }
  
    public void finish(Database.BatchableContext BC) {
      // Access initialState here 
      
    }
  }