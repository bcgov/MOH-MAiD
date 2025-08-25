// BCMOHAD-29580
@IsTest
public class ICY_UserRegistrationHandlerTest {
    
    static User userWithRoles;
    static User userWithoutRoles;

    @testSetup
    static void setupTestData() {
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'MoH Standard User' LIMIT 1];

        // User with Program Leader and region roles
        userWithRoles = new User(
            LastName = 'Henry',
            Username = 'test_with_roles@example.com',
            Alias = 'userwr',
            Email = 'userwr@example.com',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles',
            ProfileId = stdProfile.Id,
            Keycloak_Roles__c = '[ICY_Program_Leader,Comox_Valley,Delta]'
        );

        // User with no roles
        userWithoutRoles = new User(
            LastName = 'Barry',
            Username = 'test_no_roles@example.com',
            Alias = 'usernr',
            Email = 'usernr@example.com',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles',
            ProfileId = stdProfile.Id,
            Keycloak_Roles__c = ''
        );

        insert new List<User>{ userWithRoles, userWithoutRoles };
    }   

    @isTest
    static void test_assignRolesMatchingPublicGroupsToUser_noRoles() {
        
        user testuser2 = [Select id from user where LastName = 'Barry' LIMIT 1];
        Test.startTest();
        ICY_UserRegistrationHandler.assignRolesMatchingPublicGroupsToUser(testuser2.Id);
        Test.stopTest();

        List<GroupMember> members = [
            SELECT Id FROM GroupMember WHERE UserOrGroupId = :testuser2.Id
        ];
        System.assertEquals(0, members.size(), 'No groups should be assigned when Keycloak_Roles__c does not contain the admin or program roles');
    }
}