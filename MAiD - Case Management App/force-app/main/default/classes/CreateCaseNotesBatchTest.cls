@isTest
private class CreateCaseNotesBatchTest {
    @isTest static void testBatchCreatesNotes() {
         Referral__c RefRecord1 = new Referral__c();
        RefRecord1.Type_of_Referral__c = 'Organizational Referral';
        RefRecord1.Referring_Organization__c = 'Health Authority';
        RefRecord1.Individual_First_Name__c = 'Test';
        RefRecord1.Individual_Middle_Name__c = 'Middle';
        RefRecord1.Individual_Last_Name__c = 'Referral';
        RefRecord1.Individual_Preferred_Name__c = 'Ref';
        RefRecord1.Individual_Date_of_Birth__c = System.today();
        RefRecord1.Individual_Gender__c = 'Male';
        RefRecord1.Individual_Pronouns__c = 'He';
        RefRecord1.EIS_Region__c = 'Northern Region';
        RefRecord1.EIS_Location__c = 'Peace North';
        RefRecord1.Mailing_Address_same_as_Physical_Address__c = true;
        RefRecord1.Physical_Address_Line_1__c = 'Test';
        RefRecord1.Physical_Address_Postal_Code__c = 'M1J 2J1';
        RefRecord1.Physical_Address_Province__c = 'BC';
        RefRecord1.Physical_Address_City__c = 'Vancouver';
        RefRecord1.Mailing_Address_Line_1__c = 'Test';
        RefRecord1.Mailing_Address_City__c = 'Vancouver';
        RefRecord1.Mailing_Address_Postal_Code__c = 'M1J 2J1';
        RefRecord1.Mailing_Address_Province__c = 'BC';
        RefRecord1.Preferred_method_of_contact__c = 'Phone';
        RefRecord1.Individual_Home_Phone_Number__c = '2223334444';
        RefRecord1.Individual_Cell_Phone_Number__c = '3334445555';
        RefRecord1.Individual_Email_Address__c = '';
        RefRecord1.Language_in_the_Home__c = 'Mandarin';
        RefRecord1.Other_Language__c = 'Hindi';
        RefRecord1.Primary_Contact_Is_Individual_Indicator__c = false;
        RefRecord1.Is_Individual_Attending_School__c = 'Yes';
        RefRecord1.Current_School__c = 'Test School';
        RefRecord1.Who_does_the_youth_live_with__c = 'Family';
        RefRecord1.Is_stable_housing_a_concern__c = '';
        RefRecord1.Explain_housing_concern__c = 'Test Test';
        RefRecord1.Special_limitations_hearing_sight_mob__c = 'Test';
        RefRecord1.What_services_they_are_waiting_for__c = 'Test Services';
        RefRecord1.DAA_or_other_cultural_or_spiritual_repre__c = 'Test';
        RefRecord1.Referral_Notes__c = 'This is a test note.';
        RefRecord1.ICY_Show_Banner__c = TRUE;
        RefRecord1.ICY_Geographic_Area__c = 'Coast Mountains Team Hazelton';
        RefRecord1.RecordTypeId = YTS_Utility.getRecordTypeIdByDeveloperName('Referral__c', 'ICY_General'); 
        insert RefRecord1;
        
        Referral__c RefRecord2 = new Referral__c();
        RefRecord1.Type_of_Referral__c = 'Organizational Referral';
        RefRecord1.Referring_Organization__c = 'Health Authority';
        RefRecord1.Individual_First_Name__c = 'Test';
        RefRecord1.Individual_Middle_Name__c = 'Middle';
        RefRecord1.Individual_Last_Name__c = 'Referral';
        RefRecord1.Individual_Preferred_Name__c = 'Ref';
        RefRecord1.Individual_Date_of_Birth__c = System.today();
        RefRecord1.Individual_Gender__c = 'Male';
        RefRecord1.Individual_Pronouns__c = 'He';
        RefRecord1.EIS_Region__c = 'Northern Region';
        RefRecord1.EIS_Location__c = 'Peace North';
        RefRecord1.Mailing_Address_same_as_Physical_Address__c = true;
        RefRecord1.Physical_Address_Line_1__c = 'Test';
        RefRecord1.Physical_Address_Postal_Code__c = 'M1J 2J1';
        RefRecord1.Physical_Address_Province__c = 'BC';
        RefRecord1.Physical_Address_City__c = 'Vancouver';
        RefRecord1.Mailing_Address_Line_1__c = 'Test';
        RefRecord1.Mailing_Address_City__c = 'Vancouver';
        RefRecord1.Mailing_Address_Postal_Code__c = 'M1J 2J1';
        RefRecord1.Mailing_Address_Province__c = 'BC';
        RefRecord1.Preferred_method_of_contact__c = 'Phone';
        RefRecord1.Individual_Home_Phone_Number__c = '2223334444';
        RefRecord1.Individual_Cell_Phone_Number__c = '3334445555';
        RefRecord1.Individual_Email_Address__c = '';
        RefRecord1.Language_in_the_Home__c = 'Mandarin';
        RefRecord1.Other_Language__c = 'Hindi';
        RefRecord1.Primary_Contact_Is_Individual_Indicator__c = false;
        RefRecord1.Is_Individual_Attending_School__c = 'Yes';
        RefRecord1.Current_School__c = 'Test School';
        RefRecord1.Who_does_the_youth_live_with__c = 'Family';
        RefRecord1.Is_stable_housing_a_concern__c = '';
        RefRecord1.Explain_housing_concern__c = 'Test Test';
        RefRecord1.Special_limitations_hearing_sight_mob__c = 'Test';
        RefRecord1.What_services_they_are_waiting_for__c = 'Test Services';
        RefRecord1.DAA_or_other_cultural_or_spiritual_repre__c = 'Test';
        RefRecord1.Referral_Notes__c = 'This is a test note.';
        RefRecord1.ICY_Show_Banner__c = TRUE;
        RefRecord1.ICY_Geographic_Area__c = 'Coast Mountains Team Hazelton';
        RefRecord1.RecordTypeId = YTS_Utility.getRecordTypeIdByDeveloperName('Referral__c', 'ICY_General'); 
        insert RefRecord2;

        // Create test Intake records
        List<Case> cases = new List<Case>();
         Id iRecordTypeId = YTS_Utility.getRecordTypeIdByDeveloperName('Case', 'ICY_Close_Case');
        cases.add(new Case( RecordTypeId=iRecordTypeId, Referral__c =RefRecord1.id,Status='Closed', ICY_Rationale__c='Rationale 1', Case_Closed_Reason__c='Reason A'));
        cases.add(new Case( RecordTypeId=iRecordTypeId,Status='Not Started',Referral__c =RefRecord2.id,ICY_Rationale__c='Rationale 2', Case_Closed_Reason__c='Reason B')); // should be ignored
        insert cases;

       
        List<ICY_Notes__c> beforeNotes = [SELECT Id FROM ICY_Notes__c WHERE Case__c IN :cases];
        System.assertEquals(0, beforeNotes.size());

        Test.startTest();
            // execute the batch (use small batch size for deterministic behavior in tests)
            Id jobId = Database.executeBatch(new CreateCaseNotesBatch(), 50);
        Test.stopTest();

          // Verify notes created only for the closed Cases
        List<ICY_Notes__c> notes = [SELECT Id, Case__c, Description__c, Other__c FROM ICY_Notes__c WHERE Case__c IN :cases];
        System.assertEquals(1, notes.size(), 'Only one note should be created for the closed case');
        ICY_Notes__c n = notes[0];
        System.assertEquals(cases[0].Id, n.Case__c);
        System.assertEquals('Rationale 1', n.Description__c);
        System.assertEquals('Reason A', n.Other__c);


    }
}