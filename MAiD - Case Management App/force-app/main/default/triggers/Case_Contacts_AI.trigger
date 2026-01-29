trigger Case_Contacts_AI on Case_Contact__c (after insert) {

	List<Id> lstCaseContact = new List<Id>();
	if(Trigger.isInsert && Trigger.isAfter)
	{
		for(Case_Contact__c CA:Trigger.New) 
		{	 
			lstCaseContact.add(CA.id); 
		}
		ContributionLogHelper.CreateContributionFromCaseContact(lstCaseContact,'Case Contact','Create'); 
		
	}
}