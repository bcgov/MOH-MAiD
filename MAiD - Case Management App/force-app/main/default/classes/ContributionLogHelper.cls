public with sharing class ContributionLogHelper {
	//Case Contact**********************************************************************************************//
	public static void CreateContributionFromCaseContact(List<Id> plstCaseContactId,String strObjectType,String strEventType)
	{
		List<Contribution__c> lstContribution = new List<Contribution__c>();
		List<Case_Contact__c> lstCaseContact = [Select id,
												 //Recordtype.Name,
												 Case__c,
												 Case__r.Contact.Name,
												 Case__r.Individual_Preferred_Name__c,
												 CreatedBy.Contact.Region__c,
												 CreatedBy.Contact.Organization1__c
												 //Case__r.CreatedBy.Contact.Support_Team_Member_Role__c
		 										from Case_Contact__c where Id IN : plstCaseContactId];

		Profile currentUserProfile = [Select id,Name from Profile where ID =: Userinfo.getProfileId() LIMIT 1];
		String strUserProfile = currentUserProfile.Name;

		for(Case_Contact__c c:lstCaseContact)
		{
			lstContribution.add(CreateContributionFromCaseContact(C.Case__c,
													strEventType,
													strObjectType,
													C.CreatedBy.Contact.Region__c,
													c.CreatedBy.Contact.Organization1__c,
													strUserProfile,
													//c.Recordtype.Name,
													c.Case__r.Contact.Name ));
		}
		insert lstContribution;
	}


	public static Contribution__c CreateContributionFromCaseContact(id pCaseId,
														String strEventType,
														String strObjectType,
														String strRegion,
														String StrOrganization,
														String StrRole,
														//String StrRecordType,
														String StrIndividualName)
	{
		Contribution__c Con = new Contribution__c();
				Con.Case__c = pCaseId;
				Con.Action__c = strEventType;
				Con.Contribution_Type__c = strObjectType;
				if(String.isNotBlank(strRegion))
					Con.Region__c = strRegion;
				if(String.isNotBlank(StrOrganization))
					Con.Organization__c = StrOrganization;
				if(String.isNotBlank(StrRole))
					Con.User_Profile__c = StrRole;
				/*if (StrRecordType == 'Restricted')
					Con.Restricted_Indicator__c = true;
					else
					Con.Restricted_Indicator__c = false;*/
				if (String.isNotBlank(StrIndividualName))
					Con.Individual_Name__c = StrIndividualName;
			return Con;
	}
}