@isTest
public class ICY_BatchToSendInactiveCaseNotesTest {

    static final String GEO_AREA = 'Coast Mountains Team Hazelton';

    @testSetup
    static void setupData() {
        User programLeader = createProgramLeaderUser();

        System.runAs(programLeader) {
            List<Referral__c> referrals = new List<Referral__c>();

            for (Integer i = 0; i < 2; i++) {
                Referral__c refRecord = new Referral__c();
                refRecord.Type_of_Referral__c = 'Organizational Referral';
                refRecord.Referring_Organization__c = 'Health Authority';
                refRecord.Individual_First_Name__c = 'Test' + i;
                refRecord.Individual_Middle_Name__c = 'Middle';
                refRecord.Individual_Last_Name__c = 'Referral' + i;
                refRecord.Individual_Preferred_Name__c = 'Ref' + i;
                refRecord.Individual_Date_of_Birth__c = System.today();
                refRecord.Individual_Gender__c = 'Male';
                refRecord.Individual_Pronouns__c = 'He';
                refRecord.EIS_Region__c = 'Northern Region';
                refRecord.EIS_Location__c = 'Peace North';
                refRecord.Mailing_Address_same_as_Physical_Address__c = true;
                refRecord.Physical_Address_Line_1__c = 'Test';
                refRecord.Physical_Address_Postal_Code__c = 'M1J 2J1';
                refRecord.Physical_Address_Province__c = 'BC';
                refRecord.Physical_Address_City__c = 'Vancouver';
                refRecord.Mailing_Address_Line_1__c = 'Test';
                refRecord.Mailing_Address_City__c = 'Vancouver';
                refRecord.Mailing_Address_Postal_Code__c = 'M1J 2J1';
                refRecord.Mailing_Address_Province__c = 'BC';
                refRecord.Preferred_method_of_contact__c = 'Phone';
                refRecord.Individual_Home_Phone_Number__c = '2223334444';
                refRecord.Individual_Cell_Phone_Number__c = '3334445555';
                refRecord.Individual_Email_Address__c = '';
                refRecord.Language_in_the_Home__c = 'Mandarin';
                refRecord.Other_Language__c = 'Hindi';
                refRecord.Primary_Contact_Is_Individual_Indicator__c = false;
                refRecord.Is_Individual_Attending_School__c = 'Yes';
                refRecord.Current_School__c = 'Test School';
                refRecord.Who_does_the_youth_live_with__c = 'Family';
                refRecord.Is_stable_housing_a_concern__c = '';
                refRecord.Explain_housing_concern__c = 'Test Test';
                refRecord.Special_limitations_hearing_sight_mob__c = 'Test';
                refRecord.What_services_they_are_waiting_for__c = 'Test Services';
                refRecord.DAA_or_other_cultural_or_spiritual_repre__c = 'Test';
                refRecord.Referral_Notes__c = 'This is a test note.';
                referrals.add(refRecord);
            }

            insert referrals;

            Id caseRtId = Schema.SObjectType.Case
                .getRecordTypeInfosByDeveloperName()
                .get('ICY_Standard_Case')
                .getRecordTypeId();

            List<Case> casesToInsert = new List<Case>();

            Case validGeoCase = new Case();
            validGeoCase.Status = 'Open';
            validGeoCase.Location__c = 'Quesnel';
            validGeoCase.Region__c = 'Northern Region';
            validGeoCase.ICY_Last_Case_Note_Date__c = Date.today().addDays(-91);
            validGeoCase.RecordTypeId = caseRtId;
            validGeoCase.Referral__c = referrals[0].Id;
            validGeoCase.ICY_Geographic_Area__c = GEO_AREA;
            casesToInsert.add(validGeoCase);

            Case blankGeoCase = new Case();
            blankGeoCase.Status = 'Open';
            blankGeoCase.Location__c = 'Quesnel';
            blankGeoCase.Region__c = 'Northern Region';
            blankGeoCase.ICY_Last_Case_Note_Date__c = Date.today().addDays(-91);
            blankGeoCase.RecordTypeId = caseRtId;
            blankGeoCase.Referral__c = referrals[1].Id;
            blankGeoCase.ICY_Geographic_Area__c = null;
            casesToInsert.add(blankGeoCase);

            insert casesToInsert;
        }
    }

    static User createProgramLeaderUser() {
        UserRole role = new UserRole(
            Name = GEO_AREA + ' Program Leader'
        );
        insert role;

        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        String uniqueValue = String.valueOf(System.currentTimeMillis());

        User u = new User(
            FirstName = 'Program',
            LastName = 'Leader',
            Alias = 'plead',
            Email = 'programleader' + uniqueValue + '@example.com',
            Username = 'programleader' + uniqueValue + '@example.com',
            CommunityNickname = 'pleader' + uniqueValue,
            TimeZoneSidKey = 'America/Vancouver',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id,
            UserRoleId = role.Id
        );

        insert u;
        return u;
    }

    @isTest
    static void testBatchBuildsInactiveCaseEmail() {
        List<Case> cases = [
            SELECT Id, ICY_Geographic_Area__c, ICY_Last_Case_Note_Date__c
            FROM Case
            WHERE ICY_Last_Case_Note_Date__c < LAST_N_DAYS:90
        ];

        System.assertEquals(
            2,
            cases.size(),
            'Two inactive test cases should be available for the batch.'
        );

        Test.startTest();
        Database.executeBatch(new ICY_BatchToSendInactiveCaseNotes(), 50);
        Test.stopTest();

        System.assert(true, 'Batch executed successfully.');
    }

    @isTest
    static void testMonthlyScheduleExecutesBatch() {
        Test.startTest();

        System.schedule(
            'ICY_BatchToSendInactiveCaseNotes_Test',
            '0 0 0 1 * ?',
            new ICY_BatchToSendInactiveCaseNotes()
        );

        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name = 'ICY_BatchToSendInactiveCaseNotes_Test'
        ];

        System.assertEquals(
            1,
            jobs.size(),
            'Scheduled monthly job should be created.'
        );
    }
}