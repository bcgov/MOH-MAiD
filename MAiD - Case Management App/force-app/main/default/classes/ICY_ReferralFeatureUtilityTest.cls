@isTest
public class ICY_ReferralFeatureUtilityTest {
    @testSetup public static void setup() {
                   
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
        RefRecord1.ICY_Program_Leader__c=ICY_Referral_Controller.getICYPlId('Coast Mountains Team Hazelton');
        RefRecord1.RecordTypeId = YTS_Utility.getRecordTypeIdByDeveloperName('Referral__c', 'ICY_General'); 
        insert RefRecord1;
        

        case objCase = new case ();
        objCase.status = 'New';
        objCase.Origin = 'Phone';
        objCase.Referral__c =RefRecord1.id;
        objCase.RecordTypeId = YTS_Utility.getRecordTypeIdByDeveloperName('Case', 'ICY_Standard_Case');
        insert objCase;

        RefRecord1.Case__c= objCase.Id;
        update RefRecord1;

        Intake__c intake = new Intake__c();
        intake.Referral__c = RefRecord1.Id;
        intake.RecordTypeId = YTS_Utility.getRecordTypeIdByDeveloperName('Intake__c', 'ICY_Intake');
        insert intake;
        
        Case_Contact__c objCaseCon = new Case_Contact__c();
        objCaseCon.Intake__c = intake.id;
        objCaseCon.recordTypeid = YTS_Utility.getRecordTypeIdByDeveloperName('Case_Contact__c', 'ICY_Case_Contact');
        insert objCaseCon;
        
        
        User u = new User(
           // ProfileId = [SELECT Id FROM Profile WHERE Name = 'ICY Program Leader'].Id,
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id,
            LastName = 'last',
            Email = 'testLead@gov.bc.ca',
            Username = 'testLead@gov.bc.ca' + System.currentTimeMillis(),
            CompanyName = 'TEST',
            Title = 'title',
            Alias = 'alias',
            TimeZoneSidKey = 'America/Los_Angeles',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US'
        );

        User u1 = new User(
            //ProfileId = [SELECT Id FROM Profile WHERE Name = 'ICY Administrator'].Id,
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id,
            LastName = 'last',
            Email = 'testLead1@gov.bc.ca',
            Username = 'testLead1@gov.bc.ca' + System.currentTimeMillis(),
            CompanyName = 'TEST',
            Title = 'title',
            Alias = 'alias',
            TimeZoneSidKey = 'America/Los_Angeles',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US'
        );
        
        insert u;
        insert u1;
    }
    
    @isTest static void completeIntakeCtrlTest() {
        Intake__c objIntake = [SELECT id from Intake__c LIMIT 1];
        Case caseRecord = [SELECT id from Case LIMIT 1];
        
        ContentVersion cv = new ContentVersion();
        cv.VersionData = EncodingUtil.base64Decode('base64');
        cv.Title = 'fileName';
        cv.PathOnClient = 'fileName';
        Insert cv;
        
        String strDocId = [SELECT ContentDocumentId FROM ContentVersion Where Id=:cv.Id].ContentDocumentId;
        
        ICY_CompleteIntakeCtrl.createPersonAcc(objIntake.id,caseRecord.id,strDocId,'Collaborative','TestDoc',strDocId,'TestDoc2',null);
    }
    
    @isTest static void alertBannerCtrlTest1() {
        Intake__c objIntake = [SELECT id from Intake__c LIMIT 1];
        Referral__c objIRef = [SELECT id from Referral__c LIMIT 1];
        Case caseRecord = [SELECT id from Case LIMIT 1];
        user u = [Select id from User where email = 'testLead@gov.bc.ca'];
        System.runas(u){
            ICY_AlertBannerCtrl.fetchBannerDetails(objIntake.id,'Intake__c');
            ICY_AlertBannerCtrl.fetchBannerDetails(objIRef.id,'Referral__c');
            ICY_AlertBannerCtrl.fetchBannerDetails(caseRecord.id,'Case');
            ICY_AlertBannerCtrl.getProgramLeaders('Coast Mountains Team Hazelton');
        }
    }
    @isTest static void alertBannerCtrlTest2() {
        Intake__c objIntake = [SELECT id from Intake__c LIMIT 1];
        Referral__c objRef = [SELECT id from Referral__c LIMIT 1];
        Case caseRecord = [SELECT id from Case LIMIT 1];
        User u = [SELECT ID FROM USER WHERE EMAIL='testLead1@gov.bc.ca'];
        // System.runas(u){

            objRef.ICY_Assigned_To__c = u.Id;
            Update objRef;
        // }
        
        objRef.Case__c = caseRecord.id;
        Update objRef;
        
        Case_Member__c objCaseM = new Case_Member__c();
        objCaseM.Referral__c = objRef.id;
        objCaseM.ICY_Status__c = 'Active';
        insert objCaseM;
        
        ICY_AlertBannerCtrl.UpdateBannerDetails(objIntake.id,'Intake__c','TestMsg');
        ICY_AlertBannerCtrl.UpdateBannerDetails(objRef.id,'Referral__c','TestMsg');
        ICY_AlertBannerCtrl.UpdateBannerDetails(caseRecord.id,'Case','TestMsg');
        ICY_AlertBannerCtrl.getCaseTeamMembers(objRef.id);
    }
    @isTest static void alertBannerCtrlTest3() {
        Intake__c objIntake = [SELECT id from Intake__c LIMIT 1];
        Referral__c objRef = [SELECT id,Case__c,ICY_Show_Banner__c from Referral__c LIMIT 1];
        Case caseRecord = [SELECT id from Case LIMIT 1];
		user u = [Select id from User where email = 'testLead@gov.bc.ca'];
        // system.runAs(u) {
            ICY_AlertBannerCtrl.disableBannerAlert(objIntake.id,'Intake__c');
            ICY_AlertBannerCtrl.disableBannerAlert(objRef.id,'Referral__c');
            objRef.ICY_Show_Banner__c = true;
            update objRef;
            ICY_AlertBannerCtrl.disableBannerAlert(objRef.Case__c,'Case');
        // }
    }
    @isTest static void alertBannerCtrlTest4() {
        Intake__c objIntake = [SELECT id from Intake__c LIMIT 1];
        Referral__c objIRef = [SELECT id from Referral__c LIMIT 1];
        Case caseRecord = [SELECT id from Case LIMIT 1];
        user u = [Select id from User where email = 'testLead@gov.bc.ca'];
   
        // system.runAs(u) {
            ICY_AlertBannerCtrl.fetchBannerDetails(objIntake.id,'Intake__c');
            ICY_AlertBannerCtrl.fetchBannerDetails(objIRef.id,'Referral__c');
            ICY_AlertBannerCtrl.fetchBannerDetails(caseRecord.id,'Case'); 
        // }

    }
    @isTest static void alertBannerCtrlTest5() {
        Intake__c objIntake = [SELECT id from Intake__c LIMIT 1];
        user u = [Select id from User where email = 'testLead@gov.bc.ca'];
        
            
        Referral__c RefRecord = new Referral__c();
        RefRecord.Type_of_Referral__c = 'Organizational Referral';
        RefRecord.Referring_Organization__c = 'Health Authority';
        RefRecord.Individual_First_Name__c = 'Test1';
        RefRecord.Individual_Middle_Name__c = 'Middle';
        RefRecord.Individual_Last_Name__c = 'Referral';
        RefRecord.Individual_Preferred_Name__c = 'Ref';
        RefRecord.Individual_Date_of_Birth__c = System.today();
        RefRecord.Individual_Gender__c = 'Male';
        RefRecord.Individual_Pronouns__c = 'He';
        RefRecord.EIS_Region__c = 'Northern Region';
        RefRecord.EIS_Location__c = 'Peace North';
        RefRecord.Mailing_Address_same_as_Physical_Address__c = true;
        RefRecord.Physical_Address_Line_1__c = 'Test';
        RefRecord.Physical_Address_Postal_Code__c = 'M1J 2J1';
        RefRecord.Physical_Address_Province__c = 'BC';
        RefRecord.Physical_Address_City__c = 'Vancouver';
        RefRecord.Mailing_Address_Line_1__c = 'Test';
        RefRecord.Mailing_Address_City__c = 'Vancouver';
        RefRecord.Mailing_Address_Postal_Code__c = 'M1J 2J1';
        RefRecord.Mailing_Address_Province__c = 'BC';
        RefRecord.Preferred_method_of_contact__c = 'Phone';
        RefRecord.Individual_Home_Phone_Number__c = '2223334444';
        RefRecord.Individual_Cell_Phone_Number__c = '3334445555';
        RefRecord.Individual_Email_Address__c = '';
        RefRecord.Language_in_the_Home__c = 'Mandarin';
        RefRecord.Other_Language__c = 'Hindi';
        RefRecord.Primary_Contact_Is_Individual_Indicator__c = false;
        RefRecord.Is_Individual_Attending_School__c = 'Yes';
        RefRecord.Current_School__c = 'Test School';
        RefRecord.Who_does_the_youth_live_with__c = 'Family';
        RefRecord.Is_stable_housing_a_concern__c = '';
        RefRecord.Explain_housing_concern__c = 'Test Test';
        RefRecord.Special_limitations_hearing_sight_mob__c = 'Test';
        RefRecord.What_services_they_are_waiting_for__c = 'Test Services';
        RefRecord.DAA_or_other_cultural_or_spiritual_repre__c = 'Test';
        RefRecord.Referral_Notes__c = 'This is a test note.';
       	RefRecord.ICY_Show_Banner__c = TRUE;
        RefRecord.ICY_Geographic_Area__c = 'Coast Mountains Team Hazelton';   
        RefRecord.ICY_Program_Leader__c=ICY_Referral_Controller.getICYPlId('Coast Mountains Team Hazelton');
        insert RefRecord;

        case objCase1 = new case ();
        objCase1.status = 'Open';
        objCase1.Origin = 'Phone';
        objCase1.recordTypeid = YTS_Utility.getRecordTypeIdByDeveloperName('Case', 'ICY_Standard_Case');
        objCase1.Referral__c =RefRecord.id;
        insert objCase1;

        RefRecord.Case__c = objCase1.Id; 
        upsert(RefRecord);
        
		// system.runAs(u) {
            ICY_AlertBannerCtrl.fetchBannerDetails(objIntake.id,'Intake__c');
            ICY_AlertBannerCtrl.fetchBannerDetails(RefRecord.id,'Referral__c');
            ICY_AlertBannerCtrl.fetchBannerDetails(objCase1.id,'Case'); 
        // }

    }
    @isTest static void reopenCaseCtrlTest() {
        Case caseRecord = [SELECT Id,ClosedDate from Case LIMIT 1];
        caseRecord.ICY_Case_Close_Date__c = date.today();
        update caseRecord;
        
        ICY_ReopenCaseCtrl.checkClosedDate(caseRecord.Id);
        ICY_ReopenCaseCtrl.getReferralDetails(caseRecord.Id);
        
        ICY_ReopenCaseCtrl.sendEmailNotificationToLocationManager(caseRecord.Id);
     }

     @isTest
     static void closeCase_Test(){
        Case c = [SELECT id, Status from case limit 1];
        c.status = 'Closed';
        c.ICY_Geographic_Area__c = 'Coast Mountains Team Hazelton';
        Update c;
     }
        
}