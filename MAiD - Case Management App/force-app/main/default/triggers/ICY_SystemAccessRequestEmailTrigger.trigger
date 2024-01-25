trigger ICY_SystemAccessRequestEmailTrigger on System_Access_Request__c (after insert) {
  List<Messaging.SingleEmailMessage> messageList = new List<Messaging.SingleEmailMessage>();
  OrgWideEmailAddress owea = new OrgWideEmailAddress();
  owea=[select id,Address from OrgWideEmailAddress where displayname ='Integrate Support'];
  List<string> toAddress = new List<string>();
  toAddress.add(owea.Address);
  string emailTemplateName = 'ICY_Portal_Registration_Notification';
  EmailTemplate et = [SELECT Id,Subject, Body FROM EmailTemplate WHERE DeveloperName =:emailTemplateName];
   //Need a dummy contact with dummy Email for the template to be sent
  contact con=[Select id,Email from contact where Email <> '' limit 1 ];

  if (owea.Id != null  && et.Id != null && con.Id !=null ) {
    for (System_Access_Request__c sysAccRequest : Trigger.new) {
      // initialize one or more single emails as you need
      Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
      Messaging.EmailFileAttachment efa = new Messaging.EmailfileAttachment();
      // set the sender email
      message.setOrgWideEmailAddressId(owea.Id);
      // set the recipient email
      message.setToAddresses(toAddress);
     // message.setToAddresses(new String[] { 'test@test.com' });
      // set the email template id
      message.setTemplateId( et.Id);
      // do not save email as activity
      message.setSaveAsActivity(false);
      // set the id for the object
      message.setWhatId(sysAccRequest.Id);
      message.setTargetObjectId(con.id);
      // add current message to message list
      messageList.add(message);
   }
  }
  if(!messageList.isEmpty()) {
      // create savepoint before executing statement
      Savepoint sp = Database.setSavepoint();
      // send the temporary email list
      Messaging.sendEmail(messageList);
      // rollback the transaction before commiting to database
      Database.rollback(sp);

      // initialize the actual message list to be sent
      List<Messaging.SingleEmailMessage> actualMessageList = new List<Messaging.SingleEmailMessage>();

      // loop through the previous message list and set the email fields
      for (Messaging.SingleEmailMessage email : messageList) {
          Messaging.SingleEmailMessage emailToSend = new Messaging.SingleEmailMessage();
          emailToSend.setToAddresses(email.getToAddresses());
          emailToSend.setPlainTextBody(email.getPlainTextBody());
          emailToSend.setSubject(email.getSubject());
          emailToSend.setOrgWideEmailAddressId(email.getOrgWideEmailAddressId());
          emailToSend.setFileAttachments(email.getFileAttachments());
          actualMessageList.add(emailToSend);
      }
      // send the actual message list
      Messaging.SendEmailResult [] serList = Messaging.sendEmail(actualMessageList);

      // make sure the emails are sent successfully
      String errorMessage = '';
      for(Messaging.SendEmailResult ser : serList){
          if(!ser.isSuccess()){
              for(Messaging.SendEmailError err : ser.getErrors()) {
                  errorMessage += err.getMessage() + '\n';
              }
              System.debug('errorMessage:' + errorMessage);
          }
      }
  }
}