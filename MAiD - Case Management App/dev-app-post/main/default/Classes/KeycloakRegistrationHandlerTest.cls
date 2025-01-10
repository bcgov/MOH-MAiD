@isTest
public class KeycloakRegistrationHandlerTest {
  private static final String OAUTH_TOKEN = 'testToken';
  private static final String STATE = 'mocktestState';
  private static final String REFRESH_TOKEN = 'refreshToken';
  private static final String LOGIN_ID = 'testLoginId';
  private static final String USERNAME = 'testUsername';
  private static final String FIRST_NAME = 'testFirstName';
  private static final String LAST_NAME = 'testLastName';
  private static final String EMAIL_ADDRESS = 'testEmailAddress';
  private static final String LOCALE_NAME = 'testLocalName';
  private static final String FULL_NAME = FIRST_NAME + ' ' + LAST_NAME;
  private static final String PROVIDER = 'Concur';
  private static final String REDIRECT_URL = 'http://localhost/services/authcallback/orgId/Concur';
  private static final String KEY = 'testKey';
  private static final String SECRET = 'testSecret';
  private static final String STATE_TO_PROPOGATE = 'testState';
  private static final String ACCESS_TOKEN_URL = 'http://www.dummyhost.com/accessTokenUri';
  private static final String API_USER_VERSION_URL = 'http://www.dummyhost.com/user/20/1';
  private static final String AUTH_URL = 'http://www.dummy.com/authurl';
  private static final String API_USER_URL = 'www.concursolutions.com/user/api';
  private static Map<String, String> setupAuthProviderConfig() {
    Map<String, String> authProviderConfiguration = new Map<String, String>();
    authProviderConfiguration.put('Key__c', KEY);
    authProviderConfiguration.put('Auth_Url__c', AUTH_URL);
    authProviderConfiguration.put('Secret__c', SECRET);
    authProviderConfiguration.put('Access_Token_Url__c', ACCESS_TOKEN_URL);
    authProviderConfiguration.put('API_User_Url__c', API_USER_URL);
    authProviderConfiguration.put(
      'API_User_Version_Url__c',
      API_USER_VERSION_URL
    );
    authProviderConfiguration.put('Redirect_Url__c', REDIRECT_URL);
    return authProviderConfiguration;
  }
  @TestSetup
  public static void testSetup() {
    String uniqueUserName =
      'standarduser' +
      DateTime.now().getTime() +
      '@testorg.com';
    Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator'];
    List<UserRole> userRole = [SELECT Id FROM UserRole];
    String userRoleId = userRole[0].Id;
    User runningUser = new User(
      Alias = 'standt',
      Email = 'systemuser@testorg.com',
      EmailEncodingKey = 'UTF-8',
      LastName = 'Testing',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_CA',
      CommunityNickname = 'startupa',
      ProfileId = p.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      UserName = uniqueUserName,
      Override_Auto_Permission_Assignment__c = true
    );

  }

  @isTest
  public static void testCreateAndUpdateUser() {
    String uniqueUserName =
      'standarduser' +
      DateTime.now().getTime() +
      '@testorg.com';
    Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator'];
    List<UserRole> userRole = [SELECT Id FROM UserRole];
    String userRoleId = userRole[0].Id;
      KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();
      
      Map<String,String> attribmap = new Map<String,String>();
      attribmap.put('roles', '[MAiD-Manager-4]');

      Auth.UserData sampleData = new Auth.UserData(
        'testId',
        'testFirst',
        'testLast',
        'testFirst testLast',
        'testuser@example.org',
        null,
        'testuserlong',
        'en_US',
        'facebook',
        null,
        attribmap
      );
      System.debug('sampleData:' + sampleData);

      test.startTest();
      Contact c = new Contact();
      c.Birthdate = Date.newInstance(2001, 12, 9);
      c.FirstName = 'testFirst';
      c.LastName = 'testLast';
      //insert c;
      User u = handler.createUser(null, sampleData);
      System.assertEquals('testLast', u.lastName);
      System.assertEquals('testFirst', u.firstName);
      User uExists = handler.createUser(null, sampleData);
      List<Auth.UserData> users = new List<Auth.UserData>();
      List<Id> ids = new List<Id>(); 
      ids.add(u.Id);
      users.add(sampleData);
      UserRegistrationService.UpdateUsers(ids, ids, users);
      //insert (u);
      String uid = u.id;
    //}

  }

    @isTest
    static void testCanCreateUser() {
    
        Map<String,String> attribmap = new Map<String,String>();
        attribmap.put('roles', '[MAiD-Manager-4]');
        
        Auth.UserData sampleData = new Auth.UserData(
        'testId',
        'testFirst',
        'testLast',
        'testFirst testLast',
        null,
        null,
        null,
        'en_US',
        'facebook',
        null,
        attribmap
        );

        KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();
        Boolean canCreate = handler.canCreateUser(sampleData);
        System.assert(!canCreate);
    }

    @isTest
    static void testCreateUserExcep() {
        Map<String,String> attribmap = new Map<String,String>();
        attribmap.put('roles', '[MAiD-Manager-4]');
    
        Auth.UserData sampleData = new Auth.UserData(
        'testId',
        'testFirst',
        'testLast',
        'testFirst testLast',
        'testuser@example.org',
        null,
        'testuserlong',
        'en_US',
        'facebook',
        null,
        null
        );

        KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();
        Boolean exceptionThrown = false;

        try {
            handler.createUser(null, sampleData);
        } catch(Exception e) {
            exceptionThrown = true;
        }

        System.assert(exceptionThrown);
    }
    
    @isTest
    static void testDoNotCreateUser() {
    
        Map<String,String> attribmap = new Map<String,String>();
        attribmap.put('roles', '[MAiD-Manager-4]');
    
        Auth.UserData sampleData = new Auth.UserData(
        'testId',
        'testFirst',
        'testLast',
        'testFirst testLast',
        'testuser@example.org',
        'Someone',
        'Someoneelse',
        'en_US',
        'facebook',
        null,
        attribmap
        );

        KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();
        User user = handler.createUser(null, sampleData);
        
        System.assert(user != null);
    }
    
    @isTest
    static void testCreateUserExistingUser() {
        User currentUser = [Select Id, LastName, FirstName From User Where Id = :UserInfo.getUserId()];
        String testID = 'TEST_IDENTIFIER_1';
        update currentUser;
        
        Map<String,String> attribmap = new Map<String,String>();
        attribmap.put('roles', '[MAiD-Manager-4]');

        Auth.UserData sampleData = new Auth.UserData(
        testID,
        'testFirst',
        'testLast',
        'testFirst testLast',
        'testuser@example.org',
        'Someone',
        'Someoneelse',
        'en_US',
        'facebook',
        null,
        attribmap
        );

        KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();
        User user = handler.createUser(null, sampleData);
        
        System.assert(user.Id != null);
    }
    
    @isTest
    static void testUpdateUser() {
        Map<String,String> attribmap = new Map<String,String>();
        attribmap.put('roles', '[MAiD-Manager-4]');
    
        Auth.UserData sampleData = new Auth.UserData(
        'testId',
        'testFirst',
        'testLast',
        'testFirst testLast',
        'testuser@example.org',
        'Someone',
        'Someoneelse',
        'en_US',
        'facebook',
        null,
        attribmap
        );

        KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();
        handler.updateUser(UserInfo.getUserId(), null, sampleData);
        
        User user = [Select Id, LastName, FirstName From User Where Id = :UserInfo.getUserId()];
        System.assert(user.LastName == sampleData.lastName);
        System.assert(user.FirstName == sampleData.firstName);
    }
    
    @isTest
    static void testUpdateUserExcep() {
        Map<String,String> attribmap = new Map<String,String>();
        attribmap.put('roles', '[MAiD-Manager-4]');
    
        Auth.UserData sampleData = new Auth.UserData(
        'testId',
        'testFirst',
        'testLast',
        'testFirst testLast',
        'testuser@example.org',
        'Someone',
        'Someoneelse',
        'en_US',
        'facebook',
        null,
        attribmap
        );

        KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();
        Boolean exceptionThrown = false;

        try {
            handler.updateUser(null, null, sampleData);
        } catch(Exception e) {
            exceptionThrown = true;
        }

        System.assert(exceptionThrown);
    }
    
    @isTest
    static void testFetchUserMappingData() {
        UserRegistrationCustomMetadataUtility processRoles = new UserRegistrationCustomMetadataUtility();
        UserRegistrationCustomMetadataUtility loadRoles = new UserRegistrationCustomMetadataUtility('[MAiD-Manager-4]');

        List<IDP_User_Registration_Permission_Set__mdt> fetchRoles = loadRoles.ReadPermissionSet('[MAiD-Manager-4]');
        system.assert(fetchRoles != null);
    }
    
    @isTest
    static void testCheckAvailableLicense() {
        
        Boolean currentLicense = UserRegistrationService.checkAvailableLicense('Salesforce');
        
        system.assert(currentLicense == true);
    }
    
    @isTest
    static void testFetchlicenseType() {
        Map<String,String> attribmap = new Map<String,String>();
        attribmap.put('roles', '[MAiD-Manager-4]');
    
        Auth.UserData sampleData = new Auth.UserData(
        'testId',
        'testFirst',
        'testLast',
        'testFirst testLast',
        'testuser@example.org',
        'Someone',
        'Someoneelse',
        'en_US',
        'facebook',
        null,
        attribmap
        );

        String currentLicense = UserRegistrationService.fetchLicenseType(sampleData);
        
        system.assert(currentLicense == null);
    }
}