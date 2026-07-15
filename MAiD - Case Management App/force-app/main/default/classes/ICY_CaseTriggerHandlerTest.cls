@IsTest
private class ICY_CaseTriggerHandlerTest {

    private static final String OWNER_LAST_NAME = 'ICYHandlerTestOwner';

    @TestSetup
    static void setupUser() {
        Profile profileRecord = [
            SELECT Id
            FROM Profile
            WHERE Name = 'MoH Standard User'
            LIMIT 1
        ];

        insert new User(
            FirstName = 'Test',
            LastName = OWNER_LAST_NAME,
            Email = 'icy.owner@test.example',
            Username = 'icy.owner.' + DateTime.now().getTime() + '@test.example',
            Alias = 'icyownr',
            TimeZoneSidKey = 'America/Vancouver',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = profileRecord.Id
        );
    }

    @IsTest
    static void testClosedCaseSendsEmail() {
        User owner = getOwner();
        Case oldCase = createCase(owner.Id, getOpenStatus(), getGeoArea());

        Case newCase = cloneAsClosed(oldCase);
        newCase.ICY_Closed_By__c = UserInfo.getUserId();

        Test.startTest();

        ICY_CaseTriggerHandler.sendClosedCaseEmailNotificationToLead(
            new List<Case>{ newCase },
            new Map<Id, Case>{ oldCase.Id => oldCase }
        );

        Integer emailCount = Limits.getEmailInvocations();

        Test.stopTest();

        System.assertEquals(
            1,
            emailCount,
            'A notification should be sent when an ICY Standard Case is closed.'
        );
    }

    @IsTest
    static void testOwnerExcludedWhenOwnerClosesCase() {
        User owner = getOwner();
        Case oldCase = createCase(owner.Id, getOpenStatus(), getGeoArea());

        Case newCase = cloneAsClosed(oldCase);
        newCase.ICY_Closed_By__c = owner.Id;

        Test.startTest();

        ICY_CaseTriggerHandler.sendClosedCaseEmailNotificationToLead(
            new List<Case>{ newCase },
            new Map<Id, Case>{ oldCase.Id => oldCase }
        );

        Integer emailCount = Limits.getEmailInvocations();

        Test.stopTest();

        System.assertEquals(
            0,
            emailCount,
            'The owner should be excluded when the owner closes the Case.'
        );
    }

    @IsTest
    static void testClosedByBlankStillEmailsOwner() {
        User owner = getOwner();
        Case oldCase = createCase(owner.Id, getOpenStatus(), getGeoArea());

        Case newCase = cloneAsClosed(oldCase);
        newCase.ICY_Closed_By__c = null;

        Test.startTest();

        ICY_CaseTriggerHandler.sendClosedCaseEmailNotificationToLead(
            new List<Case>{ newCase },
            new Map<Id, Case>{ oldCase.Id => oldCase }
        );

        Integer emailCount = Limits.getEmailInvocations();

        Test.stopTest();

        System.assertEquals(
            1,
            emailCount,
            'The user-owned Case owner should receive the notification.'
        );
    }

    @IsTest
    static void testSkippedScenarios() {
        User owner = getOwner();
        String openStatus = getOpenStatus();

        Case blankAreaCase = createCase(owner.Id, openStatus, null);
        Case blankAreaUpdate = cloneAsClosed(blankAreaCase);

        Case unchangedCase = createCase(owner.Id, openStatus, getGeoArea());
        Case unchangedUpdate = unchangedCase.clone(true, false, false, false);

        Test.startTest();

        ICY_CaseTriggerHandler.sendClosedCaseEmailNotificationToLead(
            new List<Case>{ blankAreaUpdate },
            new Map<Id, Case>{ blankAreaCase.Id => blankAreaCase }
        );

        ICY_CaseTriggerHandler.sendClosedCaseEmailNotificationToLead(
            new List<Case>{ unchangedUpdate },
            new Map<Id, Case>{ unchangedCase.Id => unchangedCase }
        );

        ICY_CaseTriggerHandler.sendClosedCaseEmailNotificationToLead(
            new List<Case>(),
            new Map<Id, Case>()
        );

        Integer emailCount = Limits.getEmailInvocations();

        Test.stopTest();

        System.assertEquals(
            0,
            emailCount,
            'No notification should be sent for skipped scenarios.'
        );
    }

    private static Case cloneAsClosed(Case oldCase) {
        Case newCase = oldCase.clone(true, false, false, false);
        newCase.Status = 'Closed';
        return newCase;
    }

    private static Case createCase(
        Id ownerId,
        String statusValue,
        String geographicArea
    ) {
        Referral__c referral = new Referral__c(
            ICY_Referral_Source__c = 'Other',
            ICY_Referral_Source_Description__c = 'Automated test',
            Individual_First_Name__c = 'Test',
            Individual_Last_Name__c = 'Referral'
        );
        insert referral;

        Case caseRecord = new Case(
            Subject = 'ICY handler test',
            Status = statusValue,
            Origin = getActivePicklistValue(Case.Origin),
            RecordTypeId = getRecordTypeId(),
            OwnerId = ownerId,
            ICY_Geographic_Area__c = geographicArea,
            Referral__c = referral.Id
        );
        insert caseRecord;

        return caseRecord;
    }

    private static User getOwner() {
        return [
            SELECT Id
            FROM User
            WHERE LastName = :OWNER_LAST_NAME
            LIMIT 1
        ];
    }

    private static Id getRecordTypeId() {
        Schema.RecordTypeInfo recordTypeInfo =
            Case.SObjectType
                .getDescribe()
                .getRecordTypeInfosByDeveloperName()
                .get('ICY_Standard_Case');

        System.assertNotEquals(
            null,
            recordTypeInfo,
            'ICY_Standard_Case record type must exist.'
        );

        return recordTypeInfo.getRecordTypeId();
    }

    private static String getGeoArea() {
        return getActivePicklistValue(Case.ICY_Geographic_Area__c);
    }

    private static String getOpenStatus() {
        for (
            Schema.PicklistEntry entry :
            Case.Status.getDescribe().getPicklistValues()
        ) {
            if (entry.isActive() && entry.getValue() != 'Closed') {
                return entry.getValue();
            }
        }

        System.assert(false, 'An active non-Closed Case status must exist.');
        return null;
    }

    private static String getActivePicklistValue(
        Schema.SObjectField fieldToken
    ) {
        for (
            Schema.PicklistEntry entry :
            fieldToken.getDescribe().getPicklistValues()
        ) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }

        System.assert(
            false,
            'The restricted picklist must contain an active value.'
        );
        return null;
    }
}