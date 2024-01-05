public class ICY_CompleteIntakeCtrl {
    @AuraEnabled
    public static void createPersonAcc(String strRecordId,String strCaseID, String strContentDoc, String strDocumentType, 
                                        String strDocumentName, String strSignedDoc,
                                        String strSignedDocumentName, String strDocumentTypeSigned) {
        if(String.isNotBlank(strRecordId)) {
            String strReferralId = [SELECT ID,Referral__c FROM Intake__c WHERE Id =: strRecordId].Referral__c;
            Id personAccRecordTypeId = YTS_Utility.getRecordTypeIdByDeveloperName('Account', 'ICY_Person_Account');

            if(String.isNotBlank(strReferralId)) {
                Referral__c referral = [SELECT Id,
                                            Individual_Last_Name__c,
                                                Individual_Middle_Name__c,
                                                Individual_First_Name__c,
                                                Mailing_Address_same_as_Physical_Address__c,
                                                Individual_Gender__c,
                                                Individual_Pronouns__c,
                                                Individual_Date_of_Birth__c,
                                                Primary_Contact_Is_Individual_Indicator__c,
                                                Individual_Preferred_Name__c,
                                                Physical_Address_Line_1__c,
                                                Physical_Address_Line_2__c,
                                                Physical_Address_City__c,
                                                Physical_Address_Postal_Code__c,
                                                Physical_Address_Province__c,
                                                Mailing_Address_Line_1__c,
                                                Mailing_Address_Line_2__c,
                                                Mailing_Address_City__c,
                                                Mailing_Address_Province__c,
                                                Mailing_Address_Postal_Code__c,
                                                Individual_Home_Phone_Number__c,
                                                Individual_Email_Address__c,
                                                Individual_Work_Phone_Number__c,
                                                Individual_Work_Phone_Number_Extension__c,
                                                Individual_Cell_Phone_Number__c,
                                                OwnerId FROM Referral__c WHERE Id =: strReferralId];
                //Create ICY Person Account
                Account personAccount = new Account();
                personAccount.RecordTypeId = personAccRecordTypeId;
                personAccount.LastName = referral.Individual_Last_Name__c;
                personAccount.Contact_Middle_Name__pc = referral.Individual_Middle_Name__c;
                personAccount.FirstName = referral.Individual_First_Name__c;
                personAccount.Mailing_Address_same_as_Physical_Address__c = referral.Mailing_Address_same_as_Physical_Address__c;
                personAccount.Gender__c = referral.Individual_Gender__c;
                personAccount.Pronouns__c = referral.Individual_Pronouns__c;
                personAccount.PersonBirthdate = referral.Individual_Date_of_Birth__c;
                personAccount.Primary_Contact_Indicator__pc = referral.Primary_Contact_Is_Individual_Indicator__c;
                personAccount.Individual_Preferred_Name__pc = referral.Individual_Preferred_Name__c;
                //Physical Address
                if(String.isNotBlank(referral.Physical_Address_Line_1__c)){
                    personAccount.PersonOtherStreet = referral.Physical_Address_Line_1__c;
                }
                personAccount.PersonOtherCity = referral.Physical_Address_City__c;
                personAccount.PersonOtherPostalCode = referral.Physical_Address_Postal_Code__c;
                personAccount.PersonOtherState = referral.Physical_Address_Province__c;
                //Contact Info
                personAccount.PersonHomePhone = referral.Individual_Home_Phone_Number__c;
                personAccount.PersonEmail = referral.Individual_Email_Address__c;
                personAccount.Work_Phone__c = referral.Individual_Work_Phone_Number__c;
                personAccount.Work_Phone_Extension__c = referral.Individual_Work_Phone_Number_Extension__c;
                personAccount.Cell_Phone__c = referral.Individual_Cell_Phone_Number__c;
                //Insert Account
                INSERT personAccount;
                
                referral.Case__c = strCaseID;
                referral.Status__c  = 'Case Created';
                Update referral;
                
                String personAccountId= personAccount.id;
                String personAccountContactId = [Select PersonContactid from Account where Id=:personAccountId].PersonContactid;
                Case c = [SELECT Id, Referral__c, CreatedById FROM Case WHERE Id=:strCaseId ];
                c.Referral__c = referral.Id;
                c.AccountId = personAccount.Id;
                c.Contactid = personAccountContactId;
                UPDATE c;
                
                List<ICY_Document__c> icyDocs= new List<ICY_Document__c>();

                ICY_Document__c objCaseDocument = new ICY_Document__c();
                objCaseDocument.Case__c = strCaseID;
                objCaseDocument.Intake__c = strRecordId;
                //objCaseDocument.Referral__c = strReferralId;
                objCaseDocument.Name = strDocumentName;
                objCaseDocument.Document_Type__c =  strDocumentType;
                objCaseDocument.Category__c =  'Consent'; //josh
                objCaseDocument.Description__c =  'Accept/Complete Intake Document'; //josh
                icyDocs.add(objCaseDocument);
                
                if(String.isNotBlank(strSignedDoc) && String.isNotBlank(strSignedDocumentName)){
                    ICY_Document__c signedDocument = new ICY_Document__c();
                    signedDocument.Case__c = strCaseID;
                    signedDocument.Intake__c = strRecordId;
                    signedDocument.Name = strSignedDocumentName;
                    signedDocument.Document_Type__c =  strDocumentTypeSigned;
                    signedDocument.Category__c =  'Consent'; //josh
                    signedDocument.Description__c =  'Accept/Complete Intake Document'; //josh
                    icyDocs.add(signedDocument);
                }

                Insert icyDocs;
                List<ICY_Document__c> docsToUpdate = new List<ICY_Document__c>();
                List<Case_Contact__c> consToUpdate = new List<Case_Contact__c>();
            
                //Update Referral documents with Intake Id
                for(ICY_Document__c d: [SELECT Id FROM ICY_Document__c WHERE Intake__c=:strRecordId ]){
                    d.Case__c = strCaseId;
                    docsToUpdate.add(d);
                }
                //Update Referral Contacts with Intake Id
                for(Case_Contact__c cc: [SELECT Id FROM Case_Contact__c WHERE Intake__c = :strRecordId]){
                    cc.Case__c = strCaseId;
                    consToUpdate.add(cc);
                }
                if(docsToUpdate.size() > 0) UPDATE docsToUpdate;
                if(consToUpdate.size() > 0) UPDATE consToUpdate;

                Set<Id> contentDocIdSet = new Set<id>();
                
                if(String.isNotBlank(strContentDoc)) {
                    List<ContentDocumentLink> documentLinks= new List<ContentDocumentLink>();
                    ContentDocumentLink objConDocLink = new ContentDocumentLink();
                    objConDocLink.LinkedEntityId = icyDocs[0].Id;
                    objConDocLink.ContentDocumentId = strContentDoc;                    
                    documentLinks.add(objConDocLink);
                    contentDocIdSet.add(strContentDoc);

                    if(String.isNotBlank(strSignedDoc) && String.isNotBlank(strSignedDocumentName)){
                        ContentDocumentLink signedDocLink = new ContentDocumentLink();
                        signedDocLink.LinkedEntityId = icyDocs[1].Id;
                        signedDocLink.ContentDocumentId = strSignedDoc;
                        documentLinks.add(signedDocLink);
                        contentDocIdSet.add(strSignedDoc);
                    }
                    
                    Insert documentLinks;
                    DELETE [SELECT LinkedEntityId, Id, ContentDocumentId FROM ContentDocumentLink WHERE ContentDocumentId IN: contentDocIdSet AND LinkedEntityId =:strRecordId LIMIT 2];

                }
                try{
                    createCaseMemberRecordForUser(c, referral);
                    updateSharingForCaseMembers(personAccount, c, referral);
                }catch(Exception ex){
                    System.debug('$$ exception :'+ex);
                }
            }
        }
    }

    private static void createCaseMemberRecordForUser(Case c, Referral__c r){
       // Profile p = [SELECT Id, Name FROM PROFILE WHERE ID IN (SELECT PROFILEID FROM USER WHERE ID=:UserInfo.getUserId()) LIMIT 1];
       // if(p.Name == 'ICY Program Leader') return;  
        if (YTS_Utility.lookupRole('Program Leader')) return;
        Case_Member__c cm = new Case_Member__c(
            ICY_Category_Assignment__c = 'MRTM',
            ICY_Case__c = c.Id,
            Referral__c = r.Id,
            ICY_Status__c = 'Active',
            ICY_User__c = UserInfo.getUserId()
        );
        INSERT cm;
    }


    @TestVisible
    private static void updateSharingForCaseMembers(Account acct, Case c, Referral__c r){
        List<AccountShare> accountShareList = new List<AccountShare>();
        Set<Id> userIds = new Set<Id>();
        Map<Id, String> userShareMap = new Map<Id, String>();
        Case case1 = [SELECT Id, createdById FROM CASE WHERE ID =:c.Id];
        List<Case_Member__c> cmToUpdate = new List<Case_Member__c>();
        
        for(Case_Member__c cm : [SELECT Id, ICY_Case__c, Referral__c, ICY_Category_Assignment__c, ICY_User__c, ICY_Status__c FROM Case_Member__c WHERE Referral__c = :r.Id]){
            cm.ICY_Case__c = c.Id;
            if(String.isNotBlank(cm.ICY_User__c)) userIds.add(cm.ICY_User__c);
            if(cm.ICY_Status__c == 'Active'){
                if(cm.ICY_Category_Assignment__c == 'Consulting') userShareMap.put(cm.ICY_User__c, 'Read');
                else userShareMap.put(cm.ICY_User__c, 'Edit');
            }
            
            cmToUpdate.add(cm);
        }
        if(cmToUpdate.size() > 0) UPDATE cmToUpdate;


        for(Id eachUserId: userIds){
            accountShareList.add(
                new AccountShare(
                    AccountAccessLevel = userShareMap.get(eachUserId),
                    AccountId = acct.Id,
                    CaseAccessLevel = userShareMap.get(eachUserId),
                    OpportunityAccessLevel = 'None',
                    UserOrGroupId = eachUserId
                )
            );
        }

        if(accountShareList.size() > 0) INSERT accountShareList;
    }
}