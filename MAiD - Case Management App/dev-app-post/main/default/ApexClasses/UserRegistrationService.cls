/*
* Company: CGI for BC Ministry of Health
* Date: March 31, 2021
* Author: German (Herman) Ovodov, Roy Poystila
* Description: public class UserRegistrationService
*    Generic registration handler service class for an external identity provider (e.g. Keycloak)
*    Attributes:
*         NONE
*    Methods:
*         public static void createUsers(List<Id> portalId, List<Auth.UserData> data): Mass create new users
*         public static User createUser(Id portalId, Auth.UserData data): Create new user
*         public static void updateUser(Id userId, Id portalId, Auth.UserData data): Update existing user 
*         public static void deleteUser(Id userId, Id portalId, Auth.UserData data): Delete (deactivate) existing user
*
* History:
*     Initial version: March 31, 2021 - GO
*     Updates to codebase: May 1, 2021 - RP
*/


public with sharing class UserRegistrationService{
    public static final String USER_ASSIGNMENT_TYPE_PERMISSIONSET = 'Permission Set';
    public static final String USER_ASSIGNMENT_TYPE_PERMISSIONSETGROUP = 'Permission Set Group';
    public static final String USER_ASSIGNMENT_TYPE_PUBLICGROUP = 'Public Group';
    public static final String USER_ASSIGNMENT_TYPE_QUEUE = 'QUEUE';
    public static final String USER_PROVISIONING_ROLE_HGW = 'BCSC';
    public static final String SALESFORCE_USER_LICENSE_COMMUNITY = 'Community';
    public static final String SALESFORCE_USER_LICENSE_STANDARD = 'Salesforce';
    public static final String EMAIL_ASPERAND_SIGN = '@';
    public static final String ACCOUNT_PERSONACCOUNT_RECORDTYPE = 'Provider';
    public static final String BCSC_IDP_KEY = 'idp';
    public static final String MOH_IDP_KEY = 'roles';
    public static final String USER_USERNAME_REFERENCE = 'data.username';
    public static final String EMAIL_ENCODING_KEY = 'UTF-8';
    public static final String TIME_ZONE_SID_KEY = 'America/Vancouver';
    public static final String IDP_VALUE_FOR_TOKEN = 'idp';
    public static final String IDP_DEFAULT_ENDORSER_DATA_TARGET_VALUE = 'Account.HealthCloudGA__SourceSystemId__c';
    public static final String IDP_DEFAULT_HDID_TARGET_VALUE = 'Account.HDID__c';
    public static final String IDP_DEFAULT_SOURCESYSTEMID_TARGET_VALUE = 'Account.HealthCloudGA__SourceSystemId__c';
    public static final String IDP_DEFAULT_PIDP_EMAIL_TARGET_VALUE = 'Account.PersonEmail';

    public static User createUser(Id portalId, Auth.UserData data) {   
        /*
        * Description: Create new user
        * Parameters:
        *     Id portalId: Id of the portal (community) where the request originated from
        *     Auth.UserData data: UserData id token payload, including attributeMap representing the id token equivalent
        * Returns:
        *     User Object
        * 
        */
        //Verify user data
        String returnCheck = checkValidIdp(data);
        if (returnCheck == 'NO') {
            throw new Auth.AuthProviderPluginException('1000_Invalid_login_please_logout');
        }            
        
        String userdata = JSON.serialize(data.attributeMap);
        String nonRegulatedStaff = '';
        String personAccountType = '';
        Boolean createUser = true;
        String existingBcscGuid = null;

        String keyLookup = UserRegistrationService.fetchUserMappingKey(data);
        UserRegistrationCustomMetadataUtility processRoles = new UserRegistrationCustomMetadataUtility();
        UserRegistrationCustomMetadataUtility fetchRoles = new UserRegistrationCustomMetadataUtility(data.attributeMap.get(keyLookup));
        list<IDP_User_Registration_User_Mapping__mdt> userRoleList = new list<IDP_User_Registration_User_Mapping__mdt>();
        //Get user mapping record based on source IDP
        userRoleList.addAll(fetchRoles.ReadMapping(data.attributeMap.get(keyLookup)));
     
        system.debug('data:'+ json.serializePretty(data));
        User newUser = new User();
        List<User> checkUser = [
            SELECT Id, email, User_Provisioning_Role__c 
            FROM User 
            WHERE FederationIdentifier =: data.username ];
        if (checkUser.size() > 0) {
            newUser = checkUser[0];
        } 

        //Create user
        if (userRoleList.size() > 0)
        {
            for (IDP_User_Registration_User_Mapping__mdt userRoleRec : userRoleList)
            {
                system.debug('userRole_rec:' + userRoleRec );
                String keycloakRole = '';
                Boolean isHealthGatewayUser = false;
                String userName = UserRegistrationService.generateUserName(data, userRoleRec.Username_Type__c, userRoleRec.Default_Domain__c);
                if (userName.length() > 80) {
                    userName = userName.substring(1,80);
                }
                
                String emailAddress = UserRegistrationService.generateEmailAddress(data, userName);
                List<Profile> profileId = [SELECT Id FROM profile WHERE name=:userRoleRec.Salesforce_User_Profile__c LIMIT 1];
                if (profileId.size() > 0) {
                    if (userRoleRec.Knowledge_User__c) {
                        newUser.UserPermissionsKnowledgeUser = true;
                    } else {
                        newUser.UserPermissionsKnowledgeUser = false;
                    }
                    if (userRoleRec.Flow_User__c) {
                        newUser.UserPermissionsInteractionUser = true;
                    } else {
                        newUser.UserPermissionsInteractionUser = false;
                    }
                    newUser.username = userName;
                    if (newUser.email == null) {
                        if (data.attributeMap.containsKey('pidp_email')) {
                            newUser.email = data.attributeMap.get('pidp_email');
                        } else {
                            newUser.email = emailAddress;
                        }  
                    }

                    if (data.attributeMap.containsKey('family_name')) {
                        newUser.LastName = data.attributeMap.get('family_name');
                    } else {
                        newUser.lastName = data.lastName;
                    }
                    if (data.attributeMap.containsKey('given_name')) {
                        newUser.firstName = data.attributeMap.get('given_name');
                    } else {
                        newUser.firstName = data.firstName;
                    }
                    if (data.attributeMap.containsKey('roles') && !String.isBlank(String.valueOf(data.attributeMap.get('roles')))) {
    					newUser.Keycloak_Roles__c = String.valueOf(data.attributeMap.get('roles'));
						}

                    if ((data.attributeMap.containsKey('roles') || data.attributeMap.containsKey('idp')) && processRoles.isFieldExisting('User_Provisioning_Role__c', 'User')) {
                        
                        List<IDP_User_Registration_User_Mapping__mdt>  matchingRole_list = new List<IDP_User_Registration_User_Mapping__mdt>();
                        
                        matchingRole_list.addAll(manageUserRole(data)); 
                        System.debug('matchingRole_list::' + matchingRole_list);
                        String currentHost = URL.getCurrentRequestUrl().getHost();
                        system.debug('currentHost: ' + currentHost);
                        if(currentHost.toLowerCase().contains('healthgateway')) {
                            isHealthGatewayUser = true;
                        }
                        for (IDP_User_Registration_User_Mapping__mdt matchingRole_rec : matchingRole_list) {
                            if (isHealthGatewayUser) {
                                newUser.User_Provisioning_Role__c = USER_PROVISIONING_ROLE_HGW;
                            } else {
                                if (newUser.User_Provisioning_Role__c != fetchRoles.ProvidedExternalProvider) {
                                    newUser.User_Provisioning_Role__c = fetchRoles.ProvidedExternalProvider;
                                }
                            }

                        }
                    }
                    if ((data.attributeMap.containsKey('roles') || data.attributeMap.containsKey('idp')) && processRoles.isFieldExisting('CPSID__c', 'User')) {
                        List<IDP_User_Registration_User_Mapping__mdt>  matchingRole_list = new List<IDP_User_Registration_User_Mapping__mdt>();
                        
                        matchingRole_list.addAll(manageUserRole(data)); 

                        for (IDP_User_Registration_User_Mapping__mdt matchingRole_rec : matchingRole_list) {
                            String roleFilter = matchingRole_rec.External_Provider_Role__c;
                            roleFilter = roleFilter.remove('[').remove(']');
                            if (matchingRole_rec.Populate_Role_Filter__c) {
                                if (newUser.get('CPSID__c') != roleFilter) {
                                    newUser.put('CPSID__c', roleFilter);
                                }
                            }
                        }
                    }                    
                    newUser.FederationIdentifier = data.username;
                    newUser.alias = UserRegistrationService.generateUserAlias(data);
                    
                    newUser.languagelocalekey = UserInfo.getLanguage();
                    newUser.localesidkey = UserInfo.getLocale();
                    newUser.emailEncodingKey = EMAIL_ENCODING_KEY;
                    newUser.timeZoneSidKey = TIME_ZONE_SID_KEY;
                    newUser.profileId = profileId[0].Id;
                } else {
                    throw new Auth.AuthProviderPluginException('No Match found, Missing Profile Info');
                }
            }
        }
        List<IDP_User_Registration_User_Mapping__mdt>  matchingRole_list = new List<IDP_User_Registration_User_Mapping__mdt>();
                        
        matchingRole_list.addAll(manageUserRole(data)); 

        String activeUserId = '';
        try {
            /****************************************************************** */

    
            for (IDP_User_Registration_User_Mapping__mdt matchingRole_rec : matchingRole_list)
            {
                System.debug('matchingRole_rec: ' + matchingRole_rec);
                if (matchingRole_rec.Salesforce_User_License__c == SALESFORCE_USER_LICENSE_COMMUNITY)
                {
                    personAccountType = matchingRole_rec.Account_Record_Type__c;
                }
                else {
                    personAccountType = '';
                }
                if (matchingRole_rec.Salesforce_User_License__c == SALESFORCE_USER_LICENSE_COMMUNITY)
                {
                    Boolean isEndorserData = false;
                    Boolean isEndorserFound = false;
                    Boolean isEndorserValuesProvided = true;
                    Boolean isCpnFound = false;
                    Boolean isBCSCData = false;
                    Boolean isHdidMatch = false;
                    Boolean isCpnData = false;
                    Boolean isExistingAccountRequiredActive = false;
                    String contactId = null;
                    List<Account> bcscMatch = new List<Account>();
                    List<Account> endorserData = new List<Account>();
                    List<Account> cpnData = new List<Account>();
//
                    isExistingAccountRequiredActive = matchingRole_rec.is_Existing_Account_Active_Required__c == true ? true:false;
//
                    if (data.attributeMap.containsKey('idp') && data.attributeMap.containsKey('bcsc_guid')) {
                        isBCSCData = true;
                        List<String> keyValue = new List<String>();
                        keyValue.addAll(data.attributeMap.get('bcsc_guid').split(','));
                        if (!keyValue.isEmpty()) {
                            bcscMatch = fetchPersonAccount(keyValue, isExistingAccountRequiredActive, data, 'bcsc_guid');
                        }
                        
                    }
                    //lookup up when endorser_data is available
                    if (data.attributeMap.containsKey('endorser_data') 
                            && (data.attributeMap.containsKey('common_provider_number')
                            && data.attributeMap.get('common_provider_number') == '') 
                            && !matchingRole_rec.is_Ignore_License_Attribute__c) {
                        isEndorserData = true;
                        List<String> keyValue = new List<String>();

                        keyValue.addAll(data.attributeMap.get('endorser_data').remove('[').remove(']').split(','));
                        System.debug('keyValue:' + keyValue);
                        if (data.attributeMap.get('endorser_data') != '[]') {
                            endorserData = fetchPersonAccount(keyValue, isExistingAccountRequiredActive, data, 'endorser_data');
                            if (!endorserData.isEmpty()) {
                                isEndorserFound = true;
                            }
                        } else {
                            isEndorserValuesProvided = false;
                        }
                    }
                    //lookup up when common_provider_number is available
                    if (data.attributeMap.containsKey('common_provider_number') 
                            && data.attributeMap.get('common_provider_number') != ''
                            && !matchingRole_rec.is_Ignore_License_Attribute__c) {
                        isCpnData = true;
                        List<String> keyValue = new List<String>();
                        keyValue.addAll(data.attributeMap.get('common_provider_number').split(','));
                        System.debug('keyValue:' + keyValue);
                        if (data.attributeMap.get('common_provider_number') != '') {
                            cpnData = fetchPersonAccount(keyValue, isExistingAccountRequiredActive, data, 'common_provider_number');
                            if (!cpnData.isEmpty()) {
                                contactId = cpnData[0].PersonContactId;
                                isCpnFound = true;
                            }
                        }
                    }

                    // Create - 
                    String searchValue = ''; 
                    Boolean fieldExisting = false;

                    if (data.attributeMap.ContainsKey('hdid')) {
                        if (!Test.isRunningTest()) {
                            fieldExisting = fetchRoles.isFieldExisting('HDID__c','Account');
                        } else {
                            fieldExisting = fetchRoles.isFieldExisting('SourceSystemIdentifier','Account');
                        }
                        searchValue = data.attributeMap.get('hdid');
                    }                        


                    
                    if (data.attributeMap.containsKey('idp') && data.attributeMap.containsKey('hdid') 
                            && fieldExisting ) {
                        String qryString = '';
                        if (!Test.isRunningTest()) {
                            qryString = 'select id,PersonContactId, isActive from Account where HDID__c = \'' + searchValue + '\'';
                        } else {
                            qryString = 'select id,PersonContactId, isActive from Account where SourceSystemIdentifier = \'' + searchValue + '\'';
                        }
                        if (isExistingAccountRequiredActive == true) {
                            qryString += ' AND isActive = true';
                        }

                        List<Account> accountList = Database.query(qryString);
                        
                        if(accountList.size() > 0 && String.isNotBlank(accountList[0].PersonContactId)){
                            isHdidMatch = true;
                            contactId = accountList[0].PersonContactId;  
                        } else {
                            isHdidMatch = false;
                        }
                    }
                    if (data.attributeMap.containsKey('endorser_data')) {
                        String emptyEndorser = data.attributeMap.get('endorser_data');
                        if (emptyEndorser == '[]' 
                                && data.attributeMap.containsKey('pidp_email')
                                && ((!data.attributeMap.containsKey('roles') && !matchingRole_rec.is_Ignore_License_Attribute__c)
                                || (data.attributeMap.containsKey('roles') && matchingRole_rec.is_Ignore_License_Attribute__c)
                            )) {
                            throw new Auth.AuthProviderPluginException('No Match found, Endorser Data Not Provided');
                        }
                    }    

                    if (data.attributeMap.containsKey('pidp_email') 
                            && !data.attributeMap.containsKey('roles')) {
                        throw new Auth.AuthProviderPluginException('No Match found, Missing Roles Data');
                    }
                    if (bcscMatch.isEmpty() && isBCSCData && !isHdidMatch) {
                        throw new Auth.AuthProviderPluginException('No Match found for BCSC');
                    }
                    if (cpnData.isEmpty() && !isCpnFound && isCpnData) {
                        throw new Auth.AuthProviderPluginException('No Match found for CPN');
                    }
                    if (isEndorserData && (!isEndorserFound && !isHdidMatch && !isEndorserValuesProvided)) {
                        throw new Auth.AuthProviderPluginException('No Match found for Endorser Supplied Data');
                    }
                    if (!isHdidMatch && isHdidMatch != null && fieldExisting) {
                        throw new Auth.DiscoveryCustomErrorException('1000_No_Match_found_for_HDID');
                    } else if (isHdidMatch) {
                        newUser.ContactId = contactId;
                    } else if (!isCpnFound) {

                        String userPrefix = '';
                        if (data.attributeMap.containsKey('preferred_username')) {
                            String preferredUsername = data.attributeMap.get('preferred_username');

                            if (preferredUsername.contains(EMAIL_ASPERAND_SIGN)) {
                                userPrefix = preferredUsername.substringBefore(EMAIL_ASPERAND_SIGN);
                
                            } else {
                                userPrefix = preferredUsername;
                            }
                        }      
                        contactId = managePersonAccount(data, personAccountType, matchingRole_rec.isAccountSetActive__c, userPrefix);
                    }
                        
                    newUser.ContactId = contactId;
                }
            }

            // Update user role & permissionset based on latest payload
            
            for (IDP_User_Registration_User_Mapping__mdt matchingRole_rec : matchingRole_list)
            {
                if (matchingRole_rec.Salesforce_User_Role__c != Null)
                {
                    for (UserRole userRole_rec: [SELECT DeveloperName,Id,Name FROM UserRole Where Name =: matchingRole_rec.Salesforce_User_Role__c])
                    {
                        newUser.UserRoleId = userRole_rec.Id;
                    }
                }       
            }
               

            if(checkUser.size() > 0) {
                createUser = false;
                newUser.Id = checkUser[0].Id;
            }        
            if(createUser) {
                insert newUser;
            } else {
                update newUser;
            } 

            // add user to Public Group
            for (IDP_User_Registration_User_Mapping__mdt matchingRole_rec : matchingRole_list)
            {
                if (matchingRole_rec.Requires_Login_Flow__c)
                {
                    //UserRegistrationPermission.manageGroups(newUser.Id, matchingRole_rec.);
                    managePublicGroups(newUser.Id, matchingRole_rec.External_Provider_Role__c);
                }     
            }               
            activeUserId = newUser.Id;  
        }
        catch (Exception e) {
            system.debug(e.getMessage());
            //Database.rollback(sp_user);
            throw e;
            //throw new Auth.LoginDiscoveryException(e.getMessage());
        }

        return newUser;
    }
    
    public static User updateUser(Id userId, Id portalId, Auth.UserData data) {
         /*
        * Description: Update user
        * Parameters:
        *     Id userId: Id of the user logging into the system via provider
        *     Id portalId: Id of the portal (community) where the request originated from
        *     Auth.UserData data: UserData id token payload, including attributeMap representing the id token equivalent
        * Returns:
        *     None
        * 
        */       
        //Verify user data
        system.debug('data:'+ json.serializePretty(data));
        String returnCheck = checkValidIdp(data);
        if (returnCheck == 'NO') {
            throw new Auth.AuthProviderPluginException('1000_Invalid_login_please_logout');
        }            

        Boolean isEndorserData = false;
        Boolean isEndorserValuesProvided = true;
        Boolean isHdidMatch = false;
        Boolean isEndorserFound = false;
        String emptyEndorser = '';
        Boolean isHealthGatewayUser = false;

        List<Account> endorserData = new List<Account>();

        system.debug('data:'+ json.serializePretty(data));
        String keyLookup = fetchUserMappingKey(data);
        UserRegistrationCustomMetadataUtility fetchRoles = new UserRegistrationCustomMetadataUtility(data.attributeMap.get(keyLookup));

        String currentHost = URL.getCurrentRequestUrl().getHost();
        system.debug('currentHost: ' + currentHost);
        //Fetch Salesforce Id
        UserRegistrationCustomMetadataUtility processFieldcheck = new UserRegistrationCustomMetadataUtility();
        List<User> retrieveUser = new List<User>();
        User existingUser = new User();
        String qryUserString = 'SELECT Id, username, email, lastname, firstname, alias,';
        
        qryUserString += 'emailEncodingKey, timeZoneSidKey, languagelocaleKey, localesidkey ';
        if (processFieldcheck.isFieldExisting('IsPortalEnabled', 'User'))
        {
            qryUserString += ', IsPortalEnabled ';
        }

        if (processFieldcheck.isFieldExisting('User_Provisioning_Role__c', 'User')) {
            qryUserString += ', User_Provisioning_Role__c';
        }

        if (processFieldcheck.isFieldExisting('CPSID__c', 'User') ) {
            qryUserString += ', CPSID__c';
        }

        qryUserString += ' FROM User WHERE Id = \'' + userId + '\'';
        system.debug('qryUserString: ' + qryUserString);
        retrieveUser = Database.query(qryUserString);
        if (retrieveUser.size() == 1) {
            existingUser = retrieveUser[0];
        }
        
        System.debug('existingUser: ' + existingUser);              

         //Verify user data - to be removed prior to completion

        String l_userdata = JSON.serialize(data.attributeMap);

        if (data.attributeMap.containsKey('family_name')) {
            existingUser.LastName = data.attributeMap.get('family_name');
        } else {
            existingUser.lastName = data.lastName;
        }
        if (data.attributeMap.containsKey('given_name')) {
            existingUser.firstName = data.attributeMap.get('given_name');
        } else {
            existingUser.firstName = data.firstName;
        }        

        existingUser.FederationIdentifier = data.username;
         if (data.attributeMap.containsKey('roles') && !String.isBlank(String.valueOf(data.attributeMap.get('roles')))) 
         {		
            existingUser.Keycloak_Roles__c = String.valueOf(data.attributeMap.get('roles'));
		 }

        if (data.attributeMap.containsKey('endorser_data')) {
            emptyEndorser = data.attributeMap.get('endorser_data');
            if (emptyEndorser == '[]' 
                    && data.attributeMap.containsKey('pidp_email')
                    && !data.attributeMap.containsKey('roles')) {
                throw new Auth.AuthProviderPluginException('No Match found, Endorser Data Not Provided');
            }
        }          

        //lookup up when endorser_data is available
        if (data.attributeMap.containsKey('endorser_data') 
                && (data.attributeMap.containsKey('common_provider_number')
                && data.attributeMap.get('common_provider_number') == '')) {
  
            if (emptyEndorser == '[]' && !data.attributeMap.containsKey('roles')) {
                throw new Auth.AuthProviderPluginException('No Match found for Endorser Supplied Data');
            }
            isEndorserData = true;
            List<String> keyValue = new List<String>();
            
            if (data.attributeMap.get('endorser_data') != '[]') {
                keyValue.addAll(data.attributeMap.get('endorser_data').remove('[').remove(']').split(','));
                endorserData = fetchPersonAccount(keyValue, false, data, 'endorser_data');
                if (!endorserData.isEmpty()) {
                    isEndorserFound = true;
                }
            } else {
                isEndorserValuesProvided = false;
            }
        }
        User existingPortalUser = new User();

        if ((data.attributeMap.containsKey('roles') || data.attributeMap.containsKey('idp')) && processFieldcheck.isFieldExisting('User_Provisioning_Role__c', 'User')) {
            
            //keycloakRole = data.attributeMap.get('roles'); 
            currentHost = URL.getCurrentRequestUrl().getHost();
            List<IDP_User_Registration_User_Mapping__mdt>  matchingRole_list = new List<IDP_User_Registration_User_Mapping__mdt>();
            
            matchingRole_list.addAll(manageUserRole(data)); 

            if(currentHost.toLowerCase().contains('healthgateway')) {
                isHealthGatewayUser = true;
            }          
            for (IDP_User_Registration_User_Mapping__mdt matchingRole_rec : matchingRole_list) {
                if (isHealthGatewayUser) {
                    existingUser.User_Provisioning_Role__c = USER_PROVISIONING_ROLE_HGW;
                } else {
                    if (existingUser.get('User_Provisioning_Role__c') != fetchRoles.ProvidedExternalProvider) {
                        existingUser.put('User_Provisioning_Role__c', fetchRoles.ProvidedExternalProvider);
                    }
                }
            }
        }
        if ((data.attributeMap.containsKey('roles') || data.attributeMap.containsKey('idp')) && processFieldcheck.isFieldExisting('CPSID__c', 'User')) {
            //keycloakRole = data.attributeMap.get('roles'); 
            List<IDP_User_Registration_User_Mapping__mdt>  matchingRole_list = new List<IDP_User_Registration_User_Mapping__mdt>();
            
            matchingRole_list.addAll(manageUserRole(data)); 

            for (IDP_User_Registration_User_Mapping__mdt matchingRole_rec : matchingRole_list) {
                String roleFilter = matchingRole_rec.External_Provider_Role__c;
                roleFilter = roleFilter.remove('[').remove(']');
                if (matchingRole_rec.Populate_Role_Filter__c) {
                    if (existingUser.get('CPSID__c') != roleFilter) {
                        existingUser.put('CPSID__c', roleFilter);
                    }
                }

                if (matchingRole_rec.Knowledge_User__c) {
                    existingUser.UserPermissionsKnowledgeUser = true;
                } else {
                    existingUser.UserPermissionsKnowledgeUser = false;
                }        

            }
        }        
        if (processFieldcheck.isFieldExisting('IsPortalEnabled', 'User'))
        {
            if (existingUser.get('IsPortalEnabled') == true) {
                
                String qryString = '';
                qryString = 'SELECT Id, username, email,lastname,firstname,alias,emailEncodingKey,';
                qryString += ' timeZoneSidKey, languagelocaleKey, localesidkey, IsPortalEnabled, AccountId, ContactId ';

                if (processFieldcheck.isFieldExisting('OneHealthID_Name__c','Contact')) {
                    qryString += ', Contact.OneHealthID_Name__c ';
                }
                qryString += 'FROM User WHERE Id = \'' + userId + '\'';

                existingPortalUser = Database.query(qryString);
            }
        }

        if (data.attributeMap.containsKey('preferred_username')) {
            String preferredUsername = data.attributeMap.get('preferred_username');
            String userPrefix = '';
            if (preferredUsername.contains(EMAIL_ASPERAND_SIGN)) {
                userPrefix = preferredUsername.substringBefore(EMAIL_ASPERAND_SIGN);

            } else {
                userPrefix = preferredUsername;
            }
            if (processFieldcheck.isFieldExisting('OneHealthID_Name__c','Contact')) {
                if (processFieldcheck.isFieldExisting('IsPortalEnabled', 'User'))
                {
                    if (existingPortalUser.get('IsPortalEnabled') == true && userPrefix != existingPortalUser.Contact.get('OneHealthID_Name__c')) // existingPortalUser.Contact.OneHealthID_Name__c
                    {
                        Contact preferredContact = new Contact();
                        preferredContact.Id = existingPortalUser.ContactId;
                        preferredContact.put('OneHealthId_Name__c', userPrefix);

                        String json_ContactDetails = JSON.serialize(preferredContact, true);
                        //update Contact
                        updateContactDetails(json_ContactDetails);
                    }
                }
            }
        }       

        // add/update any new permission sets
        
        // add/update user role
        List<IDP_User_Registration_User_Mapping__mdt>  matchingRole_list = new List<IDP_User_Registration_User_Mapping__mdt>();

        matchingRole_list.addAll(manageUserRole(data));
        for (IDP_User_Registration_User_Mapping__mdt matchingRoleRec : matchingRole_list)
        {
            String userName = UserRegistrationService.generateUserName(data, matchingRoleRec.Username_Type__c, matchingRoleRec.Default_Domain__c);
            
            String emailAddress = UserRegistrationService.generateEmailAddress(data, userName);  
            
            if (matchingRoleRec.Flow_User__c) {
                existingUser.UserPermissionsInteractionUser = true;
            } else {
                existingUser.UserPermissionsInteractionUser = false;
            }

            Profile p = [SELECT Id FROM profile WHERE name=:matchingRoleRec.Salesforce_User_Profile__c];
            existingUser.ProfileId = p.Id;

            List<UserRole> userRoles = [SELECT DeveloperName,Id,Name FROM UserRole Where Name =: matchingRoleRec.Salesforce_User_Role__c];

            for (UserRole userRoleRec : userRoles)
            {
                existingUser.UserRoleId = userRoleRec.Id;
            }
        }
          
        try {
            update(existingUser);

        } 
        catch (Exception e) {
            System.debug(e.getMessage());
            throw e;
        }

        return existingUser;
        
    }

    private static List<Account> fetchPersonAccount(List<String> keyLookup, Boolean isActiveRequired, Auth.UserData data, String sourceAttribute) 
    {
        UserRegistrationCustomMetadataUtility utilityTool = new UserRegistrationCustomMetadataUtility();

        AttributeMapping attributes = new AttributeMapping();
        String defaultAttributeValue = IDP_DEFAULT_ENDORSER_DATA_TARGET_VALUE;
        attributes = fetchAttributeValue(data, sourceAttribute, defaultAttributeValue);
        System.debug('keyLookup_fetchvalue: ' + keyLookup);
        System.debug('sourceAttribute: ' + sourceAttribute);
        System.debug('defaultAttributeValue: ' + defaultAttributeValue);
        Boolean isNewAccount = false;
        String qryFilter = '';
        List<Account> newCommUser = new List<Account>();
        List<String> keyvalues = new List<String>();
        List<Account> existingAccount = new List<Account>();

        if (!keyLookup.isEmpty()) {
            keyvalues.addAll(keyLookup);
        } else {
            return newCommUser;
        }
        String queryFilter = String.join(new List<String>(keyvalues), '\',\'');        
        String qryString = '';
        String hcSourceSystemId = 'SourceSystemIdentifier';

        qryString = 'SELECT Id, PersonContactId, FirstName, LastName, PersonEmail, ';
        qryString += 'RecordTypeId, SourceSystemIdentifier, isActive ';
        qryString += 'FROM Account ';
        
        //String sourceSystemField = attributes.getSourceSystemField();
        if (utilityTool.isFieldExisting(attributes.Target_Field, attributes.Target_Object))
        {
            hcSourceSystemId = attributes.Target_Field;
        }
        
        if (isActiveRequired == true)
        {
            qryString += 'WHERE  isActive = true AND ' + hcSourceSystemId + ' IN (\'' + queryFilter + '\')';
            // existingAccount = [
            //     SELECT Id, PersonContactId, FirstName, LastName, PersonEmail, RecordTypeId, SourceSystemIdentifier, isActive
            //     FROM Account WHERE isActive = true AND HealthCloudGA__SourceSystemId__pc IN : keyValues 
            //     ]; 
        } else {
            qryString += 'WHERE ' + hcSourceSystemId + ' IN (\'' + queryFilter + '\')';
            // existingAccount = [
            //     SELECT Id, PersonContactId, FirstName, LastName, PersonEmail, RecordTypeId, SourceSystemIdentifier, isActive
            //     FROM Account WHERE HealthCloudGA__SourceSystemId__pc IN : keyValues 
            //     ]; 
        }
        existingAccount = Database.query(qryString);
        System.debug('qryString: ' + qryString);


        return existingAccount;
    }

    private static String managePersonAccount(Auth.UserData data, String optionalRecordType, 
            Boolean isAccountSetActive, String preferredName) 
    {
        UserRegistrationCustomMetadataUtility processRoles = new UserRegistrationCustomMetadataUtility();
        System.debug('optionalRecordType: ' + optionalRecordType);
        Boolean isNewAccount = false;
        Id newCommUser = null;
        String searchEmail = '';
        
        if (data.email!= null) {
            searchEmail = data.email;
        } else if (data.attributeMap.containsKey('pidp_email')) {
            searchEmail = data.attributeMap.get('pidp_email');
        } else {
            searchEmail = data.userName;
        }

        String qryString = '';
        if (processRoles.isFieldExisting('OneHealthID_Name__c','Contact')) {
            qryString = 'SELECT Id, PersonContactId, FirstName, LastName, PersonEmail, RecordTypeId, ';
            qryString += 'isActive, OneHealthID_Name__pc  from Account ';
            qryString += 'where PersonEmail = \'' + searchEmail + '\'';
            if (optionalRecordType != '') {
                qryString += ' AND RecordType.DeveloperName = \'' + optionalRecordType + '\'';
            }
        } else {
            qryString = 'SELECT Id, PersonContactId, FirstName, LastName, PersonEmail, RecordTypeId, ';
            qryString += 'isActive from Account ';
            qryString += 'where PersonEmail = \'' + searchEmail + '\'';
            if (optionalRecordType != '') {
                qryString += ' AND RecordType.DeveloperName = \'' + optionalRecordType + '\'';
            }            
        }

        List<Account> existingAccount = Database.query(qryString);
        Account newPersonAccount = new Account();
        
        if (existingAccount.size() == 0) 
        {
            isNewAccount = true;
            Id personAccountRecordTypeId =  Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get(optionalRecordType).getRecordTypeId();

            if (data.attributeMap.containsKey('family_name')) {
                newPersonAccount.LastName = data.attributeMap.get('family_name');
            } else {
                newPersonAccount.lastName = data.lastName;
            }
            if (data.attributeMap.containsKey('given_name')) {
                newPersonAccount.firstName = data.attributeMap.get('given_name');
            } else {
                newPersonAccount.firstName = data.firstName;
            }            

            if(data.email!= null) {
                String emailaddress = data.email;
                if (emailaddress.length() > 0) {
                    newPersonAccount.PersonEmail = emailaddress;
                } else {
                    newPersonAccount.PersonEmail = data.username;
                }
            } else if (data.attributeMap.containsKey('pidp_email')) {
                newPersonAccount.PersonEmail = data.attributeMap.get('pidp_email');
            } else {
                newPersonAccount.PersonEmail = data.userName;
            }

            newPersonAccount.RecordTypeId = personAccountRecordTypeId;
            if (isAccountSetActive) {
                newPersonAccount.isActive = true;
            } else {
                newPersonAccount.isActive = false;
            }
            // Set Account 

            if (processRoles.isFieldExisting('OneHealthID_Name__c','Contact')) {
                newPersonAccount.put('OneHealthID_Name__pc', preferredName);
            }

            insert newPersonAccount;

            newCommUser = [SELECT PersonContactId FROM Account WHERE Id =:newPersonAccount.Id ].PersonContactId;
        } else {
            newCommUser = existingAccount[0].PersonContactId;
        }

        if (!isNewAccount) {
            if (isAccountSetActive) {
                existingAccount[0].isActive = true;
            } else {
                existingAccount[0].isActive = false;
            }
        }
        return newCommUser ;
    }

    @Future
    public static void managePublicGroups(Id userId, String userProvisioningRole)
    {
        List<String> userGroups = new List<String>();
        System.debug('userId: ' + userId);
        System.debug('userProvisioningRole: ' + userProvisioningRole);
        
        UserRegistrationCustomMetadataUtility processRoles = new UserRegistrationCustomMetadataUtility(userProvisioningRole);

        for (IDP_User_Registration_Permission_Set__mdt userGroupRec : processRoles.userPermissionSet)
        {
            if (userGroupRec.Assignment_Type__c == USER_ASSIGNMENT_TYPE_PUBLICGROUP)
            {
                userGroups.add(userGroupRec.Salesforce_Public_Group__c);
            } 
            else 
            {
                if (userGroupRec.Assignment_Type__c == USER_ASSIGNMENT_TYPE_QUEUE)
                {
                    userGroups.add(userGroupRec.Salesforce_Queue__c);
                }
            }
            
        }
        if (userGroups.size() > 0)
        {
            list<groupMember> groupList = new list<groupMember>();
            list<Group> grp = [select id from Group where DeveloperName in : userGroups];
            
            for(group g : grp){
                groupMember gp = new groupMember(groupId = g.Id);
                gp.UserOrGroupId = userId;
                groupList.add(gp);
            }
                
            if(groupList.size() > 0)
            {
                insert groupList;
            }

            System.debug('GroupList: ' + groupList);
        }
 
    } 

    @Future
    public static void updateContactDetails(String contactDetails) {
        Contact contactDetail = (Contact)JSON.deserialize(contactDetails, Contact.class);
        update contactDetail;
            
    }
    
    private static List<IDP_User_Registration_User_Mapping__mdt> manageUserRole(Auth.UserData data)
    {
         /*
        * Description: Manage user role
        * Parameters:
        *     Auth.UserData data: UserData id token payload, including attributeMap representing the id token equivalent
        * Returns:
        *     IDP_User_Registration_User_Mapping__mdt: roles
        * 
        */ 

        List<IDP_User_Registration_User_Mapping__mdt> roles = new List<IDP_User_Registration_User_Mapping__mdt>();
        UserRegistrationCustomMetadataUtility processRoles = new UserRegistrationCustomMetadataUtility();

        //Determine source IDP
        if (data.attributeMap.containsKey('idp')) {
            // BCSC
            processRoles = new UserRegistrationCustomMetadataUtility(data.attributeMap.get('idp'));
            roles = processRoles.userMapping;
        } else if (data.attributemap.containsKey('roles')) {
            // MoH
            processRoles = new UserRegistrationCustomMetadataUtility(data.attributeMap.get('roles'));
            roles = processRoles.userMapping;
            
        }
        
        return roles;
    }

    public static string fetchUserMappingKey(Auth.UserData data)
    {
        String mappingKey = '';
        //Determine source IDP
        if (data.attributeMap.containsKey('idp')) {
            // BCSC
            mappingKey = 'idp';
        } else if (data.attributemap.containsKey('roles')) {
            //MoH
            mappingKey = 'roles';
        }
        return mappingKey;
    }
    
    public static string fetchLicenseType(Auth.UserData data)
    {
        String licenseType = '';
        UserRegistrationCustomMetadataUtility fetchLicenseType = New UserRegistrationCustomMetadataUtility(data.attributeMap.get('roles'));
        List<IDP_User_Registration_User_Mapping__mdt> foundRoleMaping = new List<IDP_User_Registration_User_Mapping__mdt>();
        foundRoleMaping.addAll(fetchLicenseType.ReadMapping(data.attributeMap.get('roles')));
        
        if (foundRoleMaping.size() > 0)
        {
            for (IDP_User_Registration_User_Mapping__mdt foundRoleMaping_rec : foundRoleMaping)
            {
                licenseType = foundRoleMaping_rec.Salesforce_User_License__c;
            }
        }
        Return licenseType;
    }
    public static AttributeMapping fetchAttributeValue(Auth.UserData data, String sourceAttribute, String defaultAttributeValue)
    {
        UserRegistrationCustomMetadataUtility userAttribute = new UserRegistrationCustomMetadataUtility();
        AttributeMapping mapping = new AttributeMapping();
        if (userAttribute.userAttributeMapping_map <> null && 
                userAttribute.userAttributeMapping_map.containsKey(sourceAttribute) && 
                data.attributeMap.containsKey(sourceAttribute)) {
            IDP_User_Registration_Attribute_Mapping__mdt foundAttributes = userAttribute.userAttributeMapping_map.get(sourceAttribute);
            mapping.Source_Attribute = foundAttributes.Source_Attribute_Value__c;
            mapping.Target_Object = foundAttributes.Target_Object_and_Element__c.substringBefore('.');
            mapping.Target_Field = foundAttributes.Target_Object_and_Element__c.substringAfter('.');
            mapping.Match_Required = foundAttributes.Match_Required__c;
        } else {
            mapping.Source_Attribute = sourceAttribute;
            mapping.Target_Object = defaultAttributeValue.substringBefore('.');
            mapping.Target_Field = defaultAttributeValue.substringAfter('.');
            mapping.Match_Required = false;
        }
        return mapping;

    }
    public static string generateUserName(Auth.UserData data, String nameType, String domainName)
    {
        /*
        * Description: Generate User name used in user creation/matching
        * Parameters:
        *     Auth.UserData data: UserData id token payload, including attributeMap representing the id token equivalent
                            nameType: source attribute to use for username construction
                            domainName: supplied domainName to be used when username is is not in email format
        * Returns:
        *     String: Username
        * 
        */
        String suffixName = '';
        String directoryName = domainName;
        String customDomain = URL.getSalesforceBaseUrl()
                        .toExternalForm()
                        .substringAfter('https://')
                        .substringBefore('.');
        suffixName = CustomDomain.substringAfter('--');
        if (String.isEmpty(suffixName)) {
            suffixName = customDomain;
        }
        if (data.attributeMap.containsKey('pidp_email') && !String.isEmpty(data.attributeMap.get('pidp_email'))) {
            directoryName = data.attributeMap.get('pidp_email').substringAfter(EMAIL_ASPERAND_SIGN);
        } else if (data.email != null && data.email.contains(EMAIL_ASPERAND_SIGN)) {
            if (String.isEmpty(directoryName)) {
                directoryName = data.email.substringAfter(EMAIL_ASPERAND_SIGN);
            }
        }  
        
        return data.identifier + EMAIL_ASPERAND_SIGN + directoryName + '.' + suffixName;
    }

    public static string generateEmailAddress(Auth.UserData data, String userName)
    {
        /*
        * Description: Generate/determin User email used in user creation/matching
        * Parameters:
        *     Auth.UserData data: UserData id token payload, including attributeMap representing the id token equivalent
                            userName: source attribute to use for email construction
        * Returns:
        *     String: email
        * 
        */  
        String emailAddressComplete = '';    
        //first see if attributeMap contains a valid email
        if (data.email != null && data.email.contains(EMAIL_ASPERAND_SIGN)) {
            emailAddressComplete = data.email;
        } else if (data.attributeMap.containsKey('pidp_email')) {
            emailAddressComplete = data.attributeMap.get('pidp_email');
        } else {
            emailAddressComplete = userName;
        }
        System.debug('emailAddressComplete: ' + emailAddressComplete);
        return emailAddressComplete;
    }
    public static string generateUserAlias(Auth.UserData data)
    {
        /*
        * Description: Generate User name used in user creation/matching
        * Parameters:
        *     Auth.UserData data: UserData id token payload, including attributeMap representing the id token equivalent
        * Returns:
        *     String: Username
        * 
        */
        integer unique_num = Math.mod(Math.abs(Crypto.getRandomInteger()), 10);
        return String.valueof(data.username.left(4) + '_' + String.Valueof(unique_num)).left(8);
    }
    
    public static Boolean checkAvailableLicense(String licenseType) 
    {
         /*
        * Description: look for available licenses based the value being passed in.
        * Parameters:
        *     String licenseType: License type used to verify available licenses.
        * Returns:
        *     String: Boolean
        * 
        */           
        Boolean isLicenseAvailable = false;
        UserLicense[] availableLicense_list =
            [SELECT CreatedDate,Id,LastModifiedDate,LicenseDefinitionKey,MasterLabel,Name,Status,
                SystemModstamp,TotalLicenses,UsedLicenses,UsedLicensesLastUpdated 
            FROM UserLicense where Name =: licenseType];
            
        if (availableLicense_list.size() > 0)
        {
            for(UserLicense availableLicense_rec : availableLicense_list)
            {
                if (availableLicense_rec.TotalLicenses > availableLicense_rec.UsedLicenses)
                {
                    isLicenseAvailable = true;
                }
            }
            
        }
        return isLicenseAvailable;
        
    }

    public static String checkValidIdp(Auth.UserData data) 
    {
         /*
        * Description: verify user token is a valid source.
        * Parameters:
        *     None
        * Returns:
        *     String: String
        * 
        */           
        String isValidIdp = '';
        String currentHost = URL.getCurrentRequestUrl().getHost();
        String currentIdp = '';
        Boolean matchfoundIdp = false;
        List<IDP_User_Registration_Domain_Setting__mdt> availableDomain_list = new List<IDP_User_Registration_Domain_Setting__mdt>();
        availableDomain_list =
            [SELECT Id, DeveloperName, Domain__c, Token_Source__c, Token_Attribute__c
            FROM IDP_User_Registration_Domain_Setting__mdt WHERE Domain__c =: currentHost];
            
        if (availableDomain_list.size() > 0)
        {
            for(IDP_User_Registration_Domain_Setting__mdt domainSetting_rec : availableDomain_list)
            {
                if(data.attributeMap.containsKey(domainSetting_rec.Token_Attribute__c)) {
                    currentIdp = data.attributeMap.get(domainSetting_rec.Token_Attribute__c);
                    matchfoundIdp = true;
                } else {
                    currentIdp = '';
                }

                if(currentIdp == domainSetting_rec.Token_Source__c  && matchfoundIdp == true)
                {
                    isValidIdp = 'YES';
                } else {
                    isValidIdp = 'NO';
                }
            }

        } else {
            isValidIdp = 'NA';
        }
        System.debug('isValidIdp: ' + isValidIdp);
        return isValidIdp;
        
    }

    private class CommunityUserContact
    {
        Id ContactId;
        Id AccountId;
        String AccountName;
    }
    private class AttributeMapping
    {
        String Target_Field;
        String Target_Object;
        String Source_Attribute;
        Boolean Match_Required;
    }

}