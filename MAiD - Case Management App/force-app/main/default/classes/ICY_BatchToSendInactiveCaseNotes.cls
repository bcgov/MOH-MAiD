/*
 * Sends inactive case note notifications for ICY cases.
 * Sends notification emails to the Program Leader of the geographic area with a link to the Case.
 */
global class ICY_BatchToSendInactiveCaseNotes implements Database.Batchable<SObject>,Schedulable {
    String query;
    Integer daysToCountInactiveNotes = Integer.valueof(Label.ICY_DaysForInactiveNotes);
    global static Id orgwideemailId = YTS_Utility.getICYOrgWideEmailAddressId();
    
    global void execute(SchedulableContext sc){
        ICY_BatchToSendInactiveCaseNotes b = new ICY_BatchToSendInactiveCaseNotes(); //ur batch class
      database.executebatch(b);
    }
    public Database.QueryLocator start(Database.BatchableContext BC) {
    String query =
        'SELECT Id, OwnerId, CaseNumber, ICY_Geographic_Area__c ' +
        'FROM Case ' +
        'WHERE ICY_Last_Case_Note_Date__c < LAST_N_DAYS:' + daysToCountInactiveNotes +
        ' AND Status != \'Closed\' ' +
        ' ORDER BY ICY_Geographic_Area__c';

    return Database.getQueryLocator(query);
    }
  
    public void execute(Database.BatchableContext BC, 
                        List<Case> scope) {
       List<Messaging.SingleEmailMessage> emailMsgLst = new List<Messaging.SingleEmailMessage>();
    Map<String, List<String>> geoAreaToProgramLeaderEmailMap = new Map<String, List<String>>();
       for(Case obj:scope){

          if (String.isBlank(obj.ICY_Geographic_Area__c)) {
          continue;
          }

          String geoArea = obj.ICY_Geographic_Area__c.trim();

        if (!geoAreaToProgramLeaderEmailMap.containsKey(geoArea)) {
            geoAreaToProgramLeaderEmailMap.put(
                geoArea,
                ICY_CaseNotesHandler.getProgramLeaderEmailsByGeoArea(geoArea)
            );
        }
          List<String> programLeaderEmails  = geoAreaToProgramLeaderEmailMap.get(geoArea);

           if (programLeaderEmails == null || programLeaderEmails.isEmpty()) {
                continue;
            }
           Messaging.SingleEmailMessage Emailmessage = new Messaging.SingleEmailMessage();
           Emailmessage.subject='Case Inactive';
           Emailmessage.whatId = obj.ownerId;
           Emailmessage.targetObjectId = obj.ownerId;
           Emailmessage.setToAddresses(programLeaderEmails);
           String Message = 'Hello, <br/><br/>';
           Message += 'This is a notification that case ('+'<a href="'+URL.getSalesforceBaseUrl().toExternalForm()+'/'+obj.id+'">'+obj.CaseNumber+'</a>) appears to have been inactive for over 90 days. Please follow link for more information.';
            
           Emailmessage.setHtmlBody(Message);
           Emailmessage.saveAsActivity = false;
           if(orgwideEmailId != null) {
               Emailmessage.setOrgWideEmailAddressId(orgwideEmailId);
           }
           emailMsgLst.add(Emailmessage);
       }
       if (!emailMsgLst.isEmpty() && !Test.isRunningTest()) {
            Messaging.sendEmail(emailMsgLst);
        }
    }
  
    public void finish(Database.BatchableContext BC) {
      // Access initialState here 
      
    }
  }