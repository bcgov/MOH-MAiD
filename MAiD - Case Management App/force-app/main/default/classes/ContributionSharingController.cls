/******************************************************************************************
** ICM STADD Project
*******************************************************************************************
** Class Name: Contribution sharing
** Description: Sharing Contribution records ,if the community user has access to Case 
** Version: 1.0
** 
**-----------------------------------------------------------------------------------------
**Modification Log:
**----------------
**Developer                  Date          Version               Description
**-----------------------------------------------------------------------------------------
**James GIlmour         18/1/2015         1.0                   Created** 

********************************************************************************************/
public without sharing class ContributionSharingController {

public List<Contribution__c> casrecord{get; set;}
public List<UserRecordAccess> caids{get; set;}
public List<UserRecordAccess> refids{get; set;}
public Id id{get;set;}
public Boolean rend{get; set;}
public List<Id> lstcasid;
public List<Id> lstrefid;
public string caccess;
public string racccess;
public string cid;

    public ContributionSharingController(ApexPages.StandardController controller) 
    {
        id=  ApexPages.currentPage().getParameters().get('id'); 
        casrecord = [select id,Case__c from Contribution__c where id =: id limit 1];
        if(casrecord.size () > 0)  
            cid= casrecord[0].Case__c;  
        else 
            cid = '';
        system.debug(cid);
        string userid = Userinfo.getUserId();
        
        List<User> usr = [Select Id, Username, UserType, ProfileId  FROM User where Id =: userid];
        string usrtype = usr[0].UserType;
        
        if(usrtype == 'PowerPartner')
            
        {
        
            //String strQuery = 'SELECT RecordId, HasEditAccess FROM UserRecordAccess WHERE UserId = \''+ string.escapeSingleQuotes(userid) + '\' AND ';
            if(cid != null || cid != '')
            {
                caids = [SELECT RecordId, HasAllAccess, HasEditAccess,MaxAccessLevel FROM UserRecordAccess WHERE UserId =: userid AND RecordId =:casrecord[0].Case__c];
                //strQuery = strQuery + ' (RecordID = \'' + string.escapeSingleQuotes(casid) + '\'';                
            }
            
            system.debug(caids);

            if(!caids.isempty())
            {
                 caccess = caids[0].MaxAccessLevel;
            }

            system.debug(caccess);
        
            if((caccess == 'NONE' || caccess == null))
            //if(listUserAccessRecord.Isempty()) 
            {
                //system.debug('Entered ELSE');
                ApexPages.addMessage(new ApexPages.message(ApexPages.severity.ERROR,'Insufficient Privileges: You do not have access to this record.'));
                rend=false;
                
            }
            else 
            {
                //system.debug('Entered if');
                rend=true;
            }   
        }
        else
        {
            rend=true;
        }
    
    }
}