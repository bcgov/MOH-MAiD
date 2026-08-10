@IsTest
private class ICY_CaseNotesHandlerTest {
     @testSetup static void testSetup(){
        ICY_ReferralFeatureUtilityTest.setup();
    }

    @IsTest
    static void testReferralBasedNotesUpdate() {
        Referral__c ref = [Select Id From Referral__c LIMIT 1];
         // Create ICY Note linked to Intake, with null Case__c (should be updated when Intake.Case__c is populated)
        ICY_Notes__c n1 = new ICY_Notes__c(Referral__c =  ref.Id);
        ICY_Notes__c n2 = new ICY_Notes__c(Referral__c =  ref.Id);

        insert new List<ICY_Notes__c>{ n1, n2 };

        List<Case> existingCases = [ SELECT Id, Referral__c FROM Case WHERE Referral__c = :ref.Id LIMIT 1
        ];

        Case testCase;

        if (!existingCases.isEmpty()) {
            testCase = existingCases[0];
        } else {
            testCase = new Case(
                Referral__c = ref.Id,
                Status = 'New',
                Origin = 'Web'
            );
            insert testCase;
        }

        Test.startTest();

        ICY_CaseNotesHandler.afterInsert(new List<Case>{testCase});

        Test.stopTest();

        List<ICY_Notes__c> updatedNotes = [
            SELECT Id, Case__c, Referral__c, Note_Source__c FROM ICY_Notes__c
            WHERE Id IN :new Set<Id>{ n1.Id, n2.Id }
        ];

        System.assertEquals(2, updatedNotes.size(), 'Both ICY Notes should be returned.');

        for (ICY_Notes__c note : updatedNotes) {

            System.assertEquals(ref.Id, note.Referral__c,'Referral should remain unchanged.');

            System.assertEquals(testCase.Id, note.Case__c,'Case should be populated based on the Referral.');

            System.assertEquals('Referral', note.Note_Source__c,'Note Source should be set to Referral.');
        }
    }

    @IsTest
    static void testAfterInsertEmptyInput() {

        Test.startTest();

        ICY_CaseNotesHandler.afterInsert(null);

        ICY_CaseNotesHandler.afterInsert(new List<Case>());

        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void testBlankGeographicArea() {

        Test.startTest();

        List<String> emails = ICY_CaseNotesHandler.getProgramLeaderEmailsByGeoArea(null);

        List<String> blankEmails = ICY_CaseNotesHandler.getProgramLeaderEmailsByGeoArea('');

        Test.stopTest();

        System.assertEquals(0, emails.size(),'No emails should be returned for null Geographic Area.');

        System.assertEquals(0, blankEmails.size(),'No emails should be returned for blank Geographic Area.');
    }

    @IsTest
    static void testNoMatchingQueue() {

        Test.startTest();

        List<String> emails =
            ICY_CaseNotesHandler.getProgramLeaderEmailsByGeoArea(
                    'Test Area That Does Not Exist 12345'
                );

        Test.stopTest();

        System.assertEquals(0, emails.size(),'No emails should be returned when no Queue is found.');
    }

    @IsTest
    static void testProgramLeaderEmailsExcludesICYRole() {

        String geoArea = 'Handler Test Area';

        UserRole icyRole = getOrCreateICYRole();

        User normalUser = createUser(
            'normalpl',
            null
        );

        User icyUser = createUser(
            'icyrole',
            icyRole.Id
        );

        insert new List<User>{
            normalUser,
            icyUser
        };

        Group programLeaderGroup = new Group(
            Name = 'ICY Handler Test Program Leaders',
            DeveloperName ='ICY_Handler_Test_Program_Leaders',
            Type = 'Regular'
        );

        insert programLeaderGroup;

        insert new List<GroupMember>{

            new GroupMember(
                GroupId = programLeaderGroup.Id,
                UserOrGroupId = normalUser.Id
            ),

            new GroupMember(
                GroupId = programLeaderGroup.Id,
                UserOrGroupId = icyUser.Id
            )
        };


        Group queue = new Group(
            Name = 'ICY Queue - ' + geoArea,
            DeveloperName ='ICY_Queue_Handler_Test_Area',
            Type = 'Queue'
        );

        insert queue;


        insert new GroupMember(
            GroupId = queue.Id,
            UserOrGroupId = programLeaderGroup.Id
        );


        Test.startTest();

        List<String> emails = ICY_CaseNotesHandler.getProgramLeaderEmailsByGeoArea(geoArea);

        Test.stopTest();

        System.assert(emails.contains(normalUser.Email),'Normal Program Leader should receive the notification.');


        System.assert(!emails.contains(icyUser.Email),'ICY Role user should be excluded from notifications.');


        System.assertEquals( 1, emails.size(), 'Only non-ICY Role users should be returned.');
    }

    private static UserRole getOrCreateICYRole() {

        String icyRoleDeveloperName = System.Label.ICY_User_Role;

        List<UserRole> existingRoles = [
            SELECT Id, Name, DeveloperName FROM UserRole
            WHERE DeveloperName = :icyRoleDeveloperName
            LIMIT 1
        ];

        if (!existingRoles.isEmpty()) {
            return existingRoles[0];
        }

        UserRole role = new UserRole(
            Name = 'ICY Test Role',
            DeveloperName = icyRoleDeveloperName
        );

        insert role;

        return role;
    }


    private static User createUser(
        String uniqueName,
        Id userRoleId
    ) {

        Profile profileRecord = [
            SELECT Id FROM Profile WHERE UserType = 'Standard'
            LIMIT 1
        ];

        String uniqueValue =
            String.valueOf(DateTime.now().getTime()) +
            uniqueName;

        User testUser = new User(
            FirstName = 'ICY',
            LastName = 'Test ' + uniqueName,

            Alias = uniqueName.length() > 8
                ? uniqueName.substring(0, 8)
                : uniqueName,

            Email = uniqueValue + '@example.com',

            Username = uniqueValue + '@example.com',

            CommunityNickname = 'icy' + uniqueValue,

            TimeZoneSidKey = 'America/Vancouver',

            LocaleSidKey = 'en_CA',

            EmailEncodingKey = 'UTF-8',

            LanguageLocaleKey = 'en_US',

            ProfileId = profileRecord.Id,

            UserRoleId = userRoleId
        );

        return testUser;
    }
}