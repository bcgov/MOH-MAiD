@isTest
private class GetCasePHNandVerifyTest {

    private static final String WARNING = Label.Duplicate_PHN_Warning;
    private static final String DEATH_TYPE = 'MAiD Death Foreseeable';
    private static final String PLANNING_TYPE = 'Discontinuation of Planning: Ineligible';
    private static final String OPEN_STATUS = 'Awaiting Forms';

    private static Id maidRecordTypeId() {
        return [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Case' AND DeveloperName = 'MAiD_Case'
            LIMIT 1
        ].Id;
    }

    private static Case makeCase(String phn, String caseType, String status) {
        return new Case(
            RecordTypeId = maidRecordTypeId(),
            File_Creation_Date__c = Date.today(),
            PHN__c = phn,
            Patient_Last_Name__c = 'Test',
            Patient_First_Name__c = 'PHN',
            Patient_Date_of_Birth__c = Date.newInstance(1980, 1, 1),
            Gender__c = '1 - Male',
            Type = caseType,
            Status = status,
            Date_of_MAiD__c = Date.today(),
            Case_Type_Reported_Date__c = Date.today(),
            Prevent_save_on_duplicate_PHN__c = false
        );
    }

    // MAiD Cases cannot be inserted as Closed. Create a valid open Case first, then close it.
    // The Ineligible type also requires these form fields before it can move to Closed.
    private static Case makeClosedPlanningCase(String phn) {
        Case planning = makeCase(phn, PLANNING_TYPE, OPEN_STATUS);
        planning.X1632__c = 'Yes';
        planning.X1633__c = 'Yes';
        planning.X1634__c = 'Yes';
        insert planning;

        planning = reloadCase(planning.Id);
        planning.Status = 'Closed';
        update planning;
        return reloadCase(planning.Id);
    }

    private static Case reloadCase(Id caseId) {
        return [
            SELECT Id, PHN__c, Type, Status, Prevent_save_on_duplicate_PHN__c,
                   Warning_Message_If_Any__c
            FROM Case
            WHERE Id = :caseId
        ];
    }

    private static void assertBlockedInsert(Case caseToInsert, String scenario) {
        try {
            insert caseToInsert;
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('same PHN'),
                          scenario + ' failed for an unexpected reason: ' + e.getMessage());
            return;
        }
        System.assert(false, scenario + ' should be blocked by the duplicate-PHN validation.');
    }

    private static void assertBlockedUpdate(Case caseToUpdate, String scenario) {
        try {
            update caseToUpdate;
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('same PHN'),
                          scenario + ' failed for an unexpected reason: ' + e.getMessage());
            return;
        }
        System.assert(false, scenario + ' should be blocked by the duplicate-PHN validation.');
    }

    // Scenario 1: adding Death where Planning exists warns only the new Case.
    @isTest
    static void warnsDeathAndLeavesExistingPlanningUnwarned() {
        Case existingPlanning = makeCase('1000000001', PLANNING_TYPE, OPEN_STATUS);
        insert existingPlanning;

        Case newDeath = makeCase('1000000001', DEATH_TYPE, OPEN_STATUS);
        Test.startTest();
        insert newDeath;
        Test.stopTest();
        newDeath = reloadCase(newDeath.Id);
        existingPlanning = reloadCase(existingPlanning.Id);
        System.assertEquals(WARNING, newDeath.Warning_Message_If_Any__c);
        System.assertEquals(false, newDeath.Prevent_save_on_duplicate_PHN__c);
        System.assertEquals(null, existingPlanning.Warning_Message_If_Any__c,
                            'The existing Planning Case should not receive the new Case warning.');

    }

    // Scenario 1 with the types reversed.
    @isTest
    static void warnsPlanningAndLeavesExistingDeathUnwarned() {
        Case existingDeath = makeCase('1000000002', DEATH_TYPE, OPEN_STATUS);
        insert existingDeath;

        Case newPlanning = makeCase('1000000002', PLANNING_TYPE, OPEN_STATUS);
        Test.startTest();
        insert newPlanning;
        Test.stopTest();
        newPlanning = reloadCase(newPlanning.Id);
        existingDeath = reloadCase(existingDeath.Id);
        System.assertEquals(WARNING, newPlanning.Warning_Message_If_Any__c);
        System.assertEquals(false, newPlanning.Prevent_save_on_duplicate_PHN__c);
        System.assertEquals(null, existingDeath.Warning_Message_If_Any__c,
                            'The existing Death Case should not receive the new Case warning.');
    }

    // A Case that did not already own the warning must not acquire it merely
    // because an unrelated field is edited while the opposite-type duplicate exists.
    @isTest
    static void doesNotStampWarningOnPreviouslyUnwarnedCaseDuringUnrelatedUpdate() {
        // Insert Death first, then Planning. The newly added Planning Case owns
        // the warning, while the existing Death Case remains blank.
        Case death = makeCase('1000000022', DEATH_TYPE, OPEN_STATUS);
        insert death;
        Case planning = makeCase('1000000022', PLANNING_TYPE, OPEN_STATUS);
        insert planning;

        death = reloadCase(death.Id);
        planning = reloadCase(planning.Id);
        System.assertEquals(null, death.Warning_Message_If_Any__c,
                            'The original Death Case should remain unwarned.');
        System.assertEquals(WARNING, planning.Warning_Message_If_Any__c,
                            'The newly added Planning Case should own the warning.');

        death.Description = 'Unrelated field edit';
        Test.startTest();
        update death;
        Test.stopTest();

        planning = reloadCase(planning.Id);
        death = reloadCase(death.Id);
        System.assertEquals(WARNING, planning.Warning_Message_If_Any__c,
                            'The Case that already owned the warning should retain it.');
        System.assertEquals(null, death.Warning_Message_If_Any__c,
                            'An unrelated edit must not stamp a warning on the other Case.');
    }

    // AC4: preserve the warning on its current owner while the duplicate remains.
    @isTest
    static void preservesWarningOnUnrelatedUpdateWhileDuplicateExists() {
        Case planning = makeCase('1000000023', PLANNING_TYPE, OPEN_STATUS);
        insert planning;
        Case death = makeCase('1000000023', DEATH_TYPE, OPEN_STATUS);
        insert death;

        death = reloadCase(death.Id);
        System.assertEquals(WARNING, death.Warning_Message_If_Any__c,
                            'The newly added Death Case should initially own the warning.');

        death.Description = 'Unrelated field edit';
        Test.startTest();
        update death;
        Test.stopTest();

        death = reloadCase(death.Id);
        planning = reloadCase(planning.Id);
        System.assertEquals(WARNING, death.Warning_Message_If_Any__c,
                            'The warning should remain while the duplicate exists.');
        System.assertEquals(null, planning.Warning_Message_If_Any__c,
                            'The warning should not move to the other Case.');
    }

    // AC3: after the duplicate is deleted, saving the original Case clears its stale warning.
    @isTest
    static void clearsWarningAfterDuplicateIsDeletedAndOriginalIsSaved() {
        Case planning = makeCase('1000000024', PLANNING_TYPE, OPEN_STATUS);
        insert planning;
        Case death = makeCase('1000000024', DEATH_TYPE, OPEN_STATUS);
        insert death;

        death = reloadCase(death.Id);
        System.assertEquals(WARNING, death.Warning_Message_If_Any__c,
                            'The original Case should start with the duplicate warning.');

        delete planning;

        death = reloadCase(death.Id);
        death.Description = 'Save after duplicate deletion';
        Test.startTest();
        update death;
        Test.stopTest();

        death = reloadCase(death.Id);
        System.assertEquals(null, death.Warning_Message_If_Any__c,
                            'The warning should clear after the duplicate is deleted.');
    }

    // A warning on the existing Case transfers to the newly created Case without being re-stamped.
    @isTest
    static void newDuplicateCaseOwnsWarningAfterCreation() {
        Case existingDeath = makeCase('1000000018', DEATH_TYPE, OPEN_STATUS);
        insert existingDeath;
        existingDeath = reloadCase(existingDeath.Id);
        existingDeath.Warning_Message_If_Any__c = WARNING;
        update existingDeath;

        Case newPlanning = makeCase('1000000018', PLANNING_TYPE, OPEN_STATUS);
        Test.startTest();
        insert newPlanning;
        Test.stopTest();

        existingDeath = reloadCase(existingDeath.Id);
        newPlanning = reloadCase(newPlanning.Id);
        System.assertEquals(WARNING, newPlanning.Warning_Message_If_Any__c,
                            'The new Case should carry the duplicate warning.');
        System.assertEquals(null, existingDeath.Warning_Message_If_Any__c,
                            'The existing Case warning should be cleared and not re-stamped by its trigger.');
    }

    // Scenario 2: a third Death Case is blocked when a Death/Planning pair already exists.
    @isTest
    static void blocksThirdDeathForOpenPlanningAndDeathPair() {
        insert makeCase('1000000003', PLANNING_TYPE, OPEN_STATUS);
        insert makeCase('1000000003', DEATH_TYPE, OPEN_STATUS);

        Test.startTest();
        assertBlockedInsert(makeCase('1000000003', DEATH_TYPE, OPEN_STATUS),
                            'A third Death Case');
        Test.stopTest();
    }

    // Scenario 2 with a third Planning Case.
    @isTest
    static void blocksThirdPlanningForOpenPlanningAndDeathPair() {
        insert makeCase('1000000019', PLANNING_TYPE, OPEN_STATUS);
        insert makeCase('1000000019', DEATH_TYPE, OPEN_STATUS);

        Test.startTest();
        assertBlockedInsert(makeCase('1000000019', PLANNING_TYPE, OPEN_STATUS),
                            'A third Planning Case');
        Test.stopTest();
    }

    // Scenario 3: a second Death Case with the same PHN is blocked.
    @isTest
    static void blocksSameTypeDeathDuplicate() {
        insert makeCase('1000000004', DEATH_TYPE, OPEN_STATUS);
        Test.startTest();
        assertBlockedInsert(makeCase('1000000004', DEATH_TYPE, OPEN_STATUS),
                            'A second Death Case');
        Test.stopTest();
    }

    // Scenario 4: changing a Death Case to a PHN already used by another Death Case is blocked.
    @isTest
    static void blocksDeathPhnChangeToExistingDeathPhn() {
        insert makeCase('1000000005', PLANNING_TYPE, OPEN_STATUS);
        Case movingDeath = makeCase('1000000005', DEATH_TYPE, OPEN_STATUS);
        insert movingDeath;
        insert makeCase('1000000006', DEATH_TYPE, OPEN_STATUS);

        movingDeath = reloadCase(movingDeath.Id);
        movingDeath.PHN__c = '1000000006';
        Test.startTest();
        assertBlockedUpdate(movingDeath, 'Changing a Death Case to an existing Death PHN');
        Test.stopTest();

        Case unchangedDeath = reloadCase(movingDeath.Id);
        System.assertEquals('1000000005', unchangedDeath.PHN__c,
                            'The blocked PHN change should leave the original PHN in place.');
    }
    // Scenario 6: changing a warned Death Case PHN to a unique value clears its warning.
    @isTest
    static void clearsWarningsWhenDeathPhnChangesToUniqueValue() {
        Case planning = makeCase('1000000008', PLANNING_TYPE, OPEN_STATUS);
        insert planning;
        Case death = makeCase('1000000008', DEATH_TYPE, OPEN_STATUS);
        insert death;

        death = reloadCase(death.Id);
        System.assertEquals(WARNING, death.Warning_Message_If_Any__c,
                            'The Death Case should have the duplicate warning before its PHN changes.');
        death.PHN__c = '1000000009';
        Test.startTest();
        update death;
        Test.stopTest();

        death = reloadCase(death.Id);
        planning = reloadCase(planning.Id);
        System.assertEquals(null, death.Warning_Message_If_Any__c);
        System.assertEquals(null, planning.Warning_Message_If_Any__c);
        System.assertEquals(false, death.Prevent_save_on_duplicate_PHN__c);
    }

    // Scenario 7: a warning on the other Case clears when the Death Case leaves the old PHN.
    @isTest
    static void clearsExistingPlanningWarningWhenDeathPhnChanges() {
        Case death = makeCase('1000000016', DEATH_TYPE, OPEN_STATUS);
        insert death;
        Case planning = makeCase('1000000016', PLANNING_TYPE, OPEN_STATUS);
        insert planning;

        planning = reloadCase(planning.Id);
        System.assertEquals(WARNING, planning.Warning_Message_If_Any__c);
        death = reloadCase(death.Id);
        death.PHN__c = '1000000017';
        Test.startTest();
        update death;
        Test.stopTest();

        death = reloadCase(death.Id);
        planning = reloadCase(planning.Id);
        System.assertEquals(null, death.Warning_Message_If_Any__c);
        System.assertEquals(null, planning.Warning_Message_If_Any__c);
        System.assertEquals(false, death.Prevent_save_on_duplicate_PHN__c);
    }

    // The cleanup rules also work when a Planning Case is the record whose PHN changes.
    @isTest
    static void clearsOldDeathWarningWhenPlanningPhnChanges() {
        Case death = makeCase('1000000020', DEATH_TYPE, OPEN_STATUS);
        insert death;
        Case planning = makeCase('1000000020', PLANNING_TYPE, OPEN_STATUS);
        insert planning;

        death = reloadCase(death.Id);
        death.Warning_Message_If_Any__c = WARNING;
        update death;

        planning = reloadCase(planning.Id);
        planning.PHN__c = '1000000021';
        Test.startTest();
        update planning;
        Test.stopTest();

        death = reloadCase(death.Id);
        planning = reloadCase(planning.Id);
        System.assertEquals(null, death.Warning_Message_If_Any__c);
        System.assertEquals(null, planning.Warning_Message_If_Any__c);
        System.assertEquals(false, planning.Prevent_save_on_duplicate_PHN__c);
    }

    // Scenario 8: a Planning PHN change stamps the current Case and clears the old-PHN warning.
    @isTest
    static void stampsPlanningWhenMatchingDeathHasNoWarning() {
        Case planning = makeCase('1000000010', PLANNING_TYPE, OPEN_STATUS);
        insert planning;
        Case oldDeath = makeCase('1000000010', DEATH_TYPE, OPEN_STATUS);
        insert oldDeath;
        Case newDeath = makeCase('1000000011', DEATH_TYPE, OPEN_STATUS);
        insert newDeath;

        planning = reloadCase(planning.Id);
        oldDeath = reloadCase(oldDeath.Id);
        newDeath = reloadCase(newDeath.Id);
        System.assertEquals(null, planning.Warning_Message_If_Any__c);
        System.assertEquals(WARNING, oldDeath.Warning_Message_If_Any__c);
        System.assertEquals(null, newDeath.Warning_Message_If_Any__c);

        planning.PHN__c = '1000000011';
        Test.startTest();
        update planning;
        Test.stopTest();

        planning = reloadCase(planning.Id);
        oldDeath = reloadCase(oldDeath.Id);
        newDeath = reloadCase(newDeath.Id);
        System.assertEquals(WARNING, planning.Warning_Message_If_Any__c);
        System.assertEquals(null, oldDeath.Warning_Message_If_Any__c);
        System.assertEquals(null, newDeath.Warning_Message_If_Any__c);
    }
    // Scenario 8 in reverse: populated warning transfers from Planning to changing Death Case.
    @isTest
    static void transfersWarningFromPlanningToChangingDeathCase() {
        Case oldDeath = makeCase('1000000014', DEATH_TYPE, OPEN_STATUS);
        insert oldDeath;

        // Create the target Death/Planning pair so the new Planning Case gets
        // its warning through normal automation. Delete the target Death to
        // leave the warned Planning Case as the opposite-type target.
        Case targetDeath = makeCase('1000000015', DEATH_TYPE, OPEN_STATUS);
        insert targetDeath;
        Case targetPlanning = makeCase('1000000015', PLANNING_TYPE, OPEN_STATUS);
        insert targetPlanning;
        delete targetDeath;

        targetPlanning = reloadCase(targetPlanning.Id);
        System.assertEquals(WARNING, targetPlanning.Warning_Message_If_Any__c);
        oldDeath = reloadCase(oldDeath.Id);
        oldDeath.PHN__c = '1000000015';
        Test.startTest();
        update oldDeath;
        Test.stopTest();

        oldDeath = reloadCase(oldDeath.Id);
        targetPlanning = reloadCase(targetPlanning.Id);
        System.assertEquals(WARNING, oldDeath.Warning_Message_If_Any__c);
        System.assertEquals(null, targetPlanning.Warning_Message_If_Any__c);
    }
}
