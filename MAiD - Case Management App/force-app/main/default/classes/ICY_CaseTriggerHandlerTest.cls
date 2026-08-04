@IsTest
private class ICY_CaseTriggerHandlerTest {
    private static final String OWNER = 'ICYHandlerOwner';
    private static final String LEAD = 'ICYHandlerLead';
    private static final String TEST_AREA = 'Handler Test Area';
    private static final String EMPTY_AREA = 'Handler Owner Exclusion';
    private static final String PL_GROUP = 'ICY_ACCESS_Handler_Test_Area_PL';
    private static final String EMPTY_GROUP = 'ICY_ACCESS_Handler_Owner_Exclusion_PL';
    private static final String NESTED_GROUP = 'ICY_Handler_Test_Nested_Group';

    @TestSetup
    static void setup() {
        Id profileId = [
            SELECT Id FROM Profile WHERE Name = 'MoH Standard User' LIMIT 1
        ].Id;
        String stamp = String.valueOf(DateTime.now().getTime());
        User owner = makeUser(OWNER, 'icyownr', profileId, stamp);
        User lead = makeUser(LEAD, 'icylead', profileId, stamp);
        insert new List<User>{ owner, lead };

        Group pl = makeGroup('ICY Handler Test PL', PL_GROUP);
        Group emptyPl = makeGroup('ICY Handler Empty PL', EMPTY_GROUP);
        Group nested = makeGroup('ICY Handler Nested Group', NESTED_GROUP);
        insert new List<Group>{ pl, emptyPl, nested };
        insert new List<GroupMember>{
            new GroupMember(GroupId = pl.Id, UserOrGroupId = lead.Id),
            new GroupMember(GroupId = pl.Id, UserOrGroupId = nested.Id)
        };
    }

    @IsTest
    static void testNotificationsSent() {
        User owner = getOwner();
        Case oldCase1 = makeCase(owner.Id, validArea());
        Case oldCase2 = makeCase(owner.Id, validArea());
        Case closedCase1 = closeCase(oldCase1, TEST_AREA, UserInfo.getUserId());
        Case closedCase2 = closeCase(oldCase2, TEST_AREA, null);

        Test.startTest();
        ICY_CaseTriggerHandler.sendClosedCaseEmailNotificationToLead(
            new List<Case>{ closedCase1, closedCase2 },
            new Map<Id, Case>{ oldCase1.Id => oldCase1, oldCase2.Id => oldCase2 }
        );
        Integer emailCount = Limits.getEmailInvocations();
        Test.stopTest();

        System.assertEquals(1, emailCount, 'Both valid closures should be emailed.');
    }

    @IsTest
    static void testOwnerExcludedWhenOwnerClosesCase() {
        User owner = getOwner();
        Case oldCase = makeCase(owner.Id, validArea());
        Case closedCase = closeCase(oldCase, EMPTY_AREA, owner.Id);

        Test.startTest();
        ICY_CaseTriggerHandler.sendClosedCaseEmailNotificationToLead(
            new List<Case>{ closedCase },
            new Map<Id, Case>{ oldCase.Id => oldCase }
        );
        Integer emailCount = Limits.getEmailInvocations();
        Test.stopTest();

        System.assertEquals(0, emailCount, 'The closing owner must be excluded.');
    }

    @IsTest
    static void testSkippedAndQueueOwnerBranches() {
        User owner = getOwner();
        Case missingOld = closeCase(makeCase(owner.Id, validArea()), TEST_AREA, null);

        Case blankOld = makeCase(owner.Id, null);
        Case blankArea = closeCase(blankOld, null, null);

        Case unchangedOld = makeCase(owner.Id, validArea());
        Case unchanged = unchangedOld.clone(true, false, false, false);

        Case reopenedBase = makeCase(owner.Id, validArea());
        Case reopenedOld = reopenedBase.clone(true, false, false, false);
        reopenedOld.Status = 'Closed';
        Case reopened = reopenedBase.clone(true, false, false, false);

        Case wrongTypeOld = makeCase(owner.Id, validArea());
        Case wrongType = closeCase(wrongTypeOld, TEST_AREA, null);
        wrongType.RecordTypeId = null;

        Case queueOld = makeCase(owner.Id, validArea());
        Case queueOwned = closeCase(queueOld, TEST_AREA, UserInfo.getUserId());
        queueOwned.OwnerId = getGroup(NESTED_GROUP).Id;

        Test.startTest();
        ICY_CaseTriggerHandler.sendClosedCaseEmailNotificationToLead(
            new List<Case>{ missingOld },
            new Map<Id, Case>()
        );
        ICY_CaseTriggerHandler.sendClosedCaseEmailNotificationToLead(
            new List<Case>{ blankArea, unchanged, reopened, wrongType, queueOwned },
            new Map<Id, Case>{
                blankOld.Id => blankOld,
                unchangedOld.Id => unchangedOld,
                reopenedOld.Id => reopenedOld,
                wrongTypeOld.Id => wrongTypeOld,
                queueOld.Id => queueOld
            }
        );
        Integer emailCount = Limits.getEmailInvocations();
        Test.stopTest();

        System.assertEquals(1, emailCount, 'Only the queue-owned closure should email.');
    }

    private static Case closeCase(Case oldCase, String area, Id closedById) {
        Case result = oldCase.clone(true, false, false, false);
        result.Status = 'Closed';
        result.ICY_Geographic_Area__c = area;
        result.ICY_Closed_By__c = closedById;
        return result;
    }

    private static Case makeCase(Id ownerId, String area) {
        Referral__c referral = new Referral__c(
            ICY_Referral_Source__c = 'Other',
            ICY_Referral_Source_Description__c = 'Automated test',
            Individual_First_Name__c = 'Test',
            Individual_Last_Name__c = 'Referral'
        );
        insert referral;

        Case result = new Case(
            Subject = 'ICY handler test',
            Status = openStatus(),
            Origin = activeValue(Case.Origin),
            RecordTypeId = recordTypeId(),
            OwnerId = ownerId,
            ICY_Geographic_Area__c = area,
            Referral__c = referral.Id
        );
        insert result;
        return result;
    }

    private static User makeUser(
        String lastName,
        String alias,
        Id profileId,
        String stamp
    ) {
        String username = lastName + '.' + stamp + '@test.example';
        return new User(
            FirstName = 'Test', LastName = lastName, Email = username,
            Username = username, Alias = alias, ProfileId = profileId,
            TimeZoneSidKey = 'America/Vancouver', LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US'
        );
    }

    private static Group makeGroup(String name, String developerName) {
        return new Group(Name = name, DeveloperName = developerName, Type = 'Regular');
    }

    private static User getOwner() {
        return [SELECT Id FROM User WHERE LastName = :OWNER LIMIT 1];
    }

    private static Group getGroup(String developerName) {
        return [SELECT Id FROM Group WHERE DeveloperName = :developerName LIMIT 1];
    }

    private static Id recordTypeId() {
        Schema.RecordTypeInfo info = Case.SObjectType.getDescribe()
            .getRecordTypeInfosByDeveloperName().get('ICY_Standard_Case');
        System.assertNotEquals(null, info, 'ICY Standard Case record type is required.');
        return info.getRecordTypeId();
    }

    private static String validArea() {
        return activeValue(Case.ICY_Geographic_Area__c);
    }

    private static String openStatus() {
        for (Schema.PicklistEntry entry : Case.Status.getDescribe().getPicklistValues()) {
            if (entry.isActive() && entry.getValue() != 'Closed') return entry.getValue();
        }
        System.assert(false, 'An active non-Closed status is required.');
        return null;
    }

    private static String activeValue(Schema.SObjectField fieldToken) {
        for (Schema.PicklistEntry entry : fieldToken.getDescribe().getPicklistValues()) {
            if (entry.isActive()) return entry.getValue();
        }
        System.assert(false, 'An active picklist value is required.');
        return null;
    }
}