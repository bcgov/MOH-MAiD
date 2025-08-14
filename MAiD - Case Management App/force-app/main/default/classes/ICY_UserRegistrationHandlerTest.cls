// BCMOHAD-29580
@IsTest
public class ICY_UserRegistrationHandlerTest {
    
    static User userWithRoles;
    static User userWithoutRoles;

    @testSetup
    static void setupTestData() {
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

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
            Keycloak_Roles__c = '[ICY_Program_Leader] [Comox_Valley] [Delta]'
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

        // Insert dummy _PL groups for matching
        insert new List<Group>{
            new Group(Name = 'Comox_Valley_PL', DeveloperName = 'Comox_Valley_PL', Type = 'Regular'),
            new Group(Name = 'Delta_PL', DeveloperName = 'Delta_PL', Type = 'Regular')
        };
    }

    @isTest
    static void test_assignRolesMatchingPublicGroupsToUser() {
        user testuser1 = [Select id from user where LastName = 'Henry' LIMIT 1];
        Test.startTest();
        ICY_UserRegistrationHandler.assignRolesMatchingPublicGroupsToUser(testuser1.Id);
        Test.stopTest();

        List<GroupMember> members = [
            SELECT GroupId FROM GroupMember WHERE UserOrGroupId = :testuser1.Id
        ];

       // Set<String> expectedGroupNames = new Set<String>{ 'Comox_Valley_PL', 'Delta_PL' };
        Set<Id> assignedGroupIds = new Set<Id>();
		for (GroupMember gm : members) {
    		assignedGroupIds.add(gm.GroupId);
		}

        List<Group> groups = [SELECT Id, DeveloperName FROM Group WHERE Id IN :assignedGroupIds];
        Set<String> actualGroupNames = new Set<String>();
        for (Group g : groups) {
            actualGroupNames.add(g.DeveloperName);
        }

        System.assertEquals(2, members.size(), 'Should assign 2 region-specific _PL public groups');
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