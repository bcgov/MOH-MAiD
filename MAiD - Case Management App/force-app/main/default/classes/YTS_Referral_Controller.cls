/**
 * @description       : Controller Class for New Referral creation
 * @author            : Ravi.TejaMynam@gov.bc.ca
 * @group             : Apex class
 * @last modified on  : 10-10-2021
**/
public with sharing class YTS_Referral_Controller {
    private static final String PRIMARY = 'Primary';
    private static final String REFERRAL_STR = 'Draft';
    private static final String ELIGIBILITY_PENDING = 'Eligibility Pending';

    /**
     * Aura Method to get ReferralId from Intake Id
     */
    @AuraEnabled
    public static Intake__c getReferralId(String intakeId){
        return [SELECT Referral__c, Status__c from Intake__c Where Id=:intakeId];
    }


    /**
     * Aura Method to Return the Type of Referral (ICY or YTS)
     */
    @AuraEnabled
    public static String getCurrentUserType(){
        String result;
        User u = [SELECT Id, Profile.Name FROM USER WHERE Id=:UserInfo.getUserId()];
        List<UserAppInfo> upiList = [SELECT Id, UserId, AppDefinitionId FROM UserAppInfo WHERE UserId=:UserInfo.getUserId()];
        system.debug('@@ uplist'+upiList);
        if(upiList != null && upiList.size() > 0){
            List<AppDefinition> appDef = [SELECT DurableId, UiType, Description, DeveloperName, MasterLabel, NavType, UtilityBar FROM AppDefinition WHERE DurableId=:upiList[0].AppDefinitionId];
            system.debug('@@ appDef'+appDef);
            if(appDef != null && appDef.size() > 0){
                result = appDef[0].DeveloperName; //josh dont change this, always refer to developerName here
            }
        }
        system.debug('@@ result'+result);
        if(String.isBlank(result)){
           // if(u.Profile.Name.contains('ICY'))
            if(YTS_Utility.isTopRoleICY())
                result = 'ICY';
        }
        system.debug('@@ resul2t'+result);
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static String getCaseContactRecordTypeId(){
        return YTS_Utility.getRecordTypeIdByDeveloperName('Case_Contact__c', 'ICY_Case_Contact');
    }

    /**
     * Aura Method to create new referral with concent
     */
    @AuraEnabled
    public static String createReferral(Referral__c referral, String referralId){
        if(String.isNotBlank(referralId)) referral.Id = referralId;
        referral.Consent_Received__c = true;
        referral.Status__c = REFERRAL_STR;
        referral.Sub_Status__c = ELIGIBILITY_PENDING;
        String result;
        try{
            UPSERT referral;
            result = referral.Id;
        }catch(Exception e){
            result = 'failed';
            throw new AuraHandledException(e.getMessage());
        }
        return referral.Id;
    }

    /**
     * Get Case Contacts related to Referral Record
     */
    @AuraEnabled
    public static List<Case_Contact__c> referralContacts(String referralId){
        return [SELECT Id,Contact_Person_First_Name__c, Contact_Person_Last_Name__c, Preferred_method_of_contact__c,
                Contact_Person_Home_Phone_Number__c, Contact_Person_Work_Phone_Number__c, Contact_Person_Work_Phone_Extension__c,
                Contact_Person_Cell_Phone_Number__c,Contact_Person_Email_Address__c, Mailing_Address_Line1__c,
                Mailing_Address_City__c, Mailing_Address_Postal_Code__c, Relationship_Subtype__c,
                Other_Relationship__c FROM Case_Contact__c WHERE Referral__c=:referralId];
    }

    @AuraEnabled
    public static void deleteCaseContactRecord(String caseConId){
        delete [SELECT ID FROM Case_Contact__c WHERE ID = :caseConId];
    }

    @AuraEnabled
    public static Case_Contact__c getReferralContact(String contactId){
        return [SELECT Id,Contact_Person_First_Name__c, Contact_Person_Last_Name__c, Preferred_method_of_contact__c,
                Contact_Person_Home_Phone_Number__c, Contact_Person_Work_Phone_Number__c, Contact_Person_Work_Phone_Extension__c,
                Contact_Person_Cell_Phone_Number__c,Contact_Person_Email_Address__c, Mailing_Address_Line1__c,
                Mailing_Address_City__c, Mailing_Address_Postal_Code__c, Relationship_Subtype__c,
                Other_Relationship__c, Referral__c FROM Case_Contact__c WHERE Id = :contactId LIMIT 1];
    }


    /**
     * Upsert Case Contact related to Referral Object
     */
    @AuraEnabled
    public static String upsertCaseContact(String referralId, String conId, String firstName, String lastName,
                                            String homePhone, String workPhone, String workPhoneEx, String cellPhone,
                                                String emailAddress, String relation, String otherRelation, String moc){
        Case_Contact__c c = new Case_Contact__c();
        if(String.isNotBlank(conId))
            c.Id = conId;

        c.Referral__c = referralId;
        c.Contact_Person_First_Name__c = firstName;
        c.Contact_Person_Last_Name__c = lastName;
        if(String.isNotBlank(homePhone)) c.Contact_Person_Home_Phone_Number__c = homePhone;
        if(String.isNotBlank(workPhone)) c.Contact_Person_Work_Phone_Number__c = workPhone;
        if(String.isNotBlank(workPhoneEx)) c.Contact_Person_Work_Phone_Extension__c = workPhoneEx;
        if(String.isNotBlank(cellPhone)) c.Contact_Person_Cell_Phone_Number__c = cellPhone;
        if(String.isNotBlank(emailAddress)) c.Contact_Person_Email_Address__c = emailAddress;
        if(String.isNotBlank(relation)) c.Relationship_Subtype__c = relation;
        if(String.isNotBlank(otherRelation)) c.Other_Relationship__c = otherRelation;
        if(String.isNotBlank(moc)) c.Preferred_method_of_contact__c = moc;
        c.Contact_Type__c = PRIMARY;
        upsert c;

        return c.Id;
    }

    /**
     * Retrieve Case Transition Plans
     */
    @AuraEnabled
    public static List<TransitionPlan> getCaseTransitionPlans(String caseId){
        List<TransitionPlan> result = new List<TransitionPlan>();
        for(YTS_Transition_Plan__c p: [SELECT Id, What_s_Important_to_Me__c, Transition_Domain__c, Transition_Plan_Status__c, (SELECT ID FROM Transition_Haves_And_Needs__r) FROM YTS_Transition_Plan__c WHERE Case__c = :caseId  ]){
            TransitionPlan plan = new TransitionPlan();
            plan.transitionId = p.Id;
            plan.domain = p.Transition_Domain__c;
            plan.whatsImpToMe = p.What_s_Important_to_Me__c;
            plan.planStatus = p.Transition_Plan_Status__c;
            if(String.isNotEmpty(plan.whatsImpToMe) || p.Transition_Haves_And_Needs__r.size() >= 1){
                plan.showBadge = true;
            } else {
                plan.showBadge = false;
            }
            //For Lightning icon on the UI
            switch on p.Transition_Domain__c {
                when  'Relationships'{
                    plan.icon = 'standard:asset_relationship';
                    plan.tabClass = 'slds-vertical-tabs__nav-item slds-is-active';
                    plan.sortOrder = 1;
                }
                when 'Team'{
                    plan.icon = 'standard:customers';
                    plan.tabClass = 'slds-vertical-tabs__nav-item';
                    plan.sortOrder = 2;
                }
                when 'Identity, Culture and Community'{
                    plan.icon = 'standard:employee_organization';
                    plan.tabClass = 'slds-vertical-tabs__nav-item';
                    plan.sortOrder = 3;
                }
                when 'Money Management'{
                    plan.icon = 'standard:partner_fund_allocation';
                    plan.tabClass = 'slds-vertical-tabs__nav-item';
                    plan.sortOrder = 4;
                }
                when 'Physical Health'{
                    plan.icon = 'standard:medication_statement';
                    plan.tabClass = 'slds-vertical-tabs__nav-item';
                    plan.sortOrder = 5;
                }
                when 'Mental Health and Wellness'{
                    plan.icon = 'standard:lead';
                    plan.tabClass = 'slds-vertical-tabs__nav-item';
                    plan.sortOrder = 6;
                }
                when 'Housing'{
                    plan.icon = 'standard:household';
                    plan.tabClass = 'slds-vertical-tabs__nav-item';
                    plan.sortOrder = 7;
                }
                when 'Job Readiness and Employment'{
                    plan.icon = 'standard:employee_organization';
                    plan.tabClass = 'slds-vertical-tabs__nav-item';
                    plan.sortOrder = 8;
                }
                when 'Education'{
                    plan.icon = 'standard:education';
                    plan.tabClass = 'slds-vertical-tabs__nav-item';
                    plan.sortOrder = 9;
                }
                when 'Life Skills'{
                    plan.icon = 'standard:skill';
                    plan.tabClass = 'slds-vertical-tabs__nav-item';
                    plan.sortOrder = 10;
                }
            }
            result.add(plan);
        }
        return result;
    }


    /**
     * Retrieve Haves and Needs
     *
     */
    @AuraEnabled
    public static List<PlanHaves> getTransitionHaves(String transitionPlanId){
        List<PlanHaves> result = new List<PlanHaves>();
        for(YTS_Haves_And_Needs__c h: [SELECT Id, Contact_Organization__c, Details__c, Have__c, Transition_Plan__c, End_Date__c,Have_Need_Other_Description__c,Need_Status__c FROM YTS_Haves_And_Needs__c WHERE Transition_Plan__c =:transitionPlanId and Have__c != NULL ORDER BY CreatedDate DESC]){
            PlanHaves p = new PlanHaves();
            p.contact = h.Contact_Organization__c;
            p.details = h.Details__c;
            p.have = (h.Have__c == 'Other')?h.Have_Need_Other_Description__c:h.Have__c;
            p.transitionPlanId = h.Transition_Plan__c;
            p.recordId = h.Id;
            p.status = h.Need_Status__c;
            if(h.End_Date__c != null)
                p.endDate = YTS_Utility.dateFormat_eeeeMMMdyyyy(h.End_Date__c);
            result.add(p);
        }

        return result;
    }

    /**
     * Retrieve Haves and Needs
     *
     */
    @AuraEnabled
    public static List<PlanNeeds> getTransitionNeeds(String transitionPlanId){
        YTS_Transition_Plan__c plan = [SELECT Case__c FROM YTS_Transition_Plan__c WHERE ID=:transitionPlanId];
        Boolean isCaseClosed = false;
        String caseStatus = getCaseStatus(plan.Case__c);
        if(caseStatus == 'Closed')
            isCaseClosed = true;

        List<PlanNeeds> result = new List<PlanNeeds>();
        Set<Id> needIds = new Set<Id>();
        String profileName = YTS_Notes_Documents_Controller.getUserProfileName();
        Boolean isSysadmin = false;
        if(profileName == 'System Administrator') isSysadmin = true;
        Map<Id, YTS_Haves_And_Needs__c> needsMap = new Map<Id, YTS_Haves_And_Needs__c>([
            SELECT Id, Contact_Organization__c, Details__c, Need__c, Need_Status__c, Transition_Plan__c, Start_Date__c,Have_Need_Other_Description__c FROM YTS_Haves_And_Needs__c WHERE Transition_Plan__c =:transitionPlanId and Need__c != NULL ORDER BY CreatedDate DESC
        ]);

        Map<Id, YTS_Goal_Steps__c> goalStepMap = new Map<Id, YTS_Goal_Steps__c>([
            SELECT Id, Action_Goal_Description__c, Current_Stage__c, Title__c, Transition_Needs__c, Step_Completed_By__c, Assigned_Case_Team_Member__r.Name, Assigned_Case_Team_Member__c   , Who_Is_Supporting_this__c FROM YTS_Goal_Steps__c WHERE Transition_Needs__c IN :needsMap.keySet()
        ]);


        for(YTS_Haves_And_Needs__c h: needsMap.values()){
            PlanNeeds p = new PlanNeeds();
            List<NeedSteps> needSteps = new List<NeedSteps>();
            p.contact = h.Contact_Organization__c;
            p.details = h.Details__c;
            p.need = (h.Need__c == 'Other')?h.Have_Need_Other_Description__c:h.Need__c;
            p.transitionPlanId = h.Transition_Plan__c;
            p.recordId = h.Id;
            p.status = h.Need_Status__c;
            if(h.Start_Date__c != null) p.startDate = YTS_Utility.dateFormat_eeeeMMMdyyyy(h.Start_Date__c);

            //Need Goal Steps
            for(YTS_Goal_Steps__c s: goalStepMap.values()){
                if(s.Transition_Needs__c == h.Id){
                    NeedSteps gs = new NeedSteps();
                    gs.recordId = s.Id;
                    gs.actionToMeetGoal = s.Action_Goal_Description__c;
                    gs.stage = s.Current_Stage__c;
                    gs.stepCompletedBy = YTS_Utility.dateFormat_eeeeMMMdyyyy(s.Step_Completed_By__c);
                    gs.title = s.Title__c;
                    gs.transitionNeedId = s.Transition_Needs__c;
                    gs.whoIsSupporting = s.Who_Is_Supporting_this__c;
                    gs.caseTeamMember = s.Assigned_Case_Team_Member__r.Name;
                    gs.isGoalStepEditable = false;
                    if(isCaseClosed) gs.isGoalStepEditable = false;
                    gs.isGoalStepDeletable = isSysadmin;
                    needSteps.add(gs);
                }
            }
            if(needSteps.size() > 0) p.needSteps = needSteps;
            result.add(p);
        }
        return result;
    }

    /**
     * Retrieve Have Or Need Record
     */
    @AuraEnabled
    public static YTS_Haves_And_Needs__c getHaveNeedRecord(String recordId){
        return [SELECT Id, ICY_Has_Agreement_Been_Captured__c,Need_Status__c,Contact_Organization__c, Details__c, Have__c, Need__c, Start_Date__c, Transition_Plan__c, End_Date__c,Have_Need_Other_Description__c FROM YTS_Haves_And_Needs__c WHERE Id =:recordId LIMIT 1];
    }

    /**
     * Retrieve Goal Steps records
     */
    @AuraEnabled
    public static YTS_Goal_Steps__c getStepRecord(String recordId){
        return [SELECT Id, Action_Goal_Description__c, Current_Stage__c, Title__c, Step_Completed_By__c,Who_Is_Supporting_this__c, Assigned_Case_Team_Member__c FROM YTS_Goal_Steps__c WHERE Id =:recordId LIMIT 1];
    }

    /**
     * Get Account Id by Case Id
     */
    @AuraEnabled(cacheable=true)
    public static String getCaseAccountId(String caseId){
        return [select id, AccountId from Case where id =:caseId].AccountId;
    }

    /**
     * get Case status
     */
    @AuraEnabled
    public static String getCaseStatus(String caseId){
        return [select Id, Status FROM CASE WHERE ID = :caseId].Status;
    }

    /**
     * get all transition steps related to
     */
    @AuraEnabled
    public static List<TransitionGoalSteps> getTransitionSteps(String caseId, List<String> filterCriteria){
        Set<Id> transitionIds = new Set<Id>();
        Set<Id> transitonneedIds = new Set<Id>();
        Set<Id> stepIds = new Set<Id>();
        List<TransitionGoalSteps> result = new List<TransitionGoalSteps>();

        for(YTS_Transition_Plan__c p: [SELECT Id FROM YTS_Transition_Plan__c WHERE Case__c = :caseId  ]){
            transitionIds.add(p.Id);
        }

        for(YTS_Haves_And_Needs__c h: [SELECT Id FROM YTS_Haves_And_Needs__c WHERE Transition_Plan__c IN :transitionIds]){
            transitonneedIds.add(h.Id);
        }

        for(YTS_Goal_Steps__c s: [SELECT Id, Action_Goal_Description__c, Current_Stage__c, Title__c, Transition_Plan_Domain__c, Assigned_Case_Team_Member__r.Name,
                                        Step_Completed_By__c, Who_Is_Supporting_this__c FROM YTS_Goal_Steps__c
                                        WHERE Transition_Needs__c IN :transitonneedIds and Current_Stage__c IN :filterCriteria]){
            TransitionGoalSteps g = new TransitionGoalSteps();
            g.recordId = s.Id;
            g.domain = s.Transition_Plan_Domain__c;
            g.title = s.Title__c;
            g.action = s.Action_Goal_Description__c;
            g.stepTobeCompleted = s.Step_Completed_By__c;
            g.supportedBy = s.Who_Is_Supporting_this__c;
            g.stage = s.Current_Stage__c;
            g.caseTeamMember = s.Assigned_Case_Team_Member__r.Name;
            result.add(g);
        }

        return result;
    }


    @AuraEnabled
    public static List<CaseTeamWrapper> getCaseTeam(String caseId){
        List<CaseTeamWrapper> result = new List<CaseTeamWrapper>();
        Set<Id> caseUserIds = new Set<Id>();
        Set<Id> caseContactIds = new Set<Id>();
        for(CaseTeamMember ct: [SELECT Id, memberId FROM CaseTeamMember WHERE ParentId=:caseId]){
            if(ct.memberId.getSobjectType() == Schema.User.SObjectType){
                caseUserIds.add(ct.memberId);
            }else{
                caseContactIds.add(ct.memberId);
            }
        }
        for(User u: [SELECT Id, Name FROM USER WHERE ID IN :caseUserIds]){
            CaseTeamWrapper temp = new CaseTeamWrapper();
            temp.userOrContactId = u.Id;
            temp.userName = u.Name;
            result.add(temp);
        }
        return result;
    }


    /**
     * get all Current User's assigned Goal Steps
     */
    @AuraEnabled
    public static List<TransitionGoalSteps> getMyGoalSteps(){
        List<TransitionGoalSteps> result = new List<TransitionGoalSteps>();
        for(YTS_Goal_Steps__c s: [SELECT Id, Action_Goal_Description__c, Current_Stage__c, Title__c, Transition_Plan_Domain__c,
                                        Step_Completed_By__c, Who_Is_Supporting_this__c, Assigned_Case_Team_Member__c, Individual_Preferred_Name__c,
                                        Assigned_Case_Team_Member__r.Name FROM YTS_Goal_Steps__c WHERE Assigned_Case_Team_Member__c=:UserInfo.getUserId()]){
            TransitionGoalSteps g = new TransitionGoalSteps();
            g.recordId = s.Id;
            g.domain = s.Transition_Plan_Domain__c;
            g.title = s.Title__c;
            g.action = s.Action_Goal_Description__c;
            g.stepTobeCompleted = s.Step_Completed_By__c;
            g.supportedBy = s.Who_Is_Supporting_this__c;
            g.stage = s.Current_Stage__c;
            g.individualName = s.Individual_Preferred_Name__c;
            g.caseTeamMember = s.Assigned_Case_Team_Member__r.Name;
            result.add(g);
        }
        return result;
    }

    @AuraEnabled
    public static void updateRecordType(String contactId){
        String staddRTId = YTS_Utility.getRecordTypeIdByDeveloperName('Case_Contact__c', 'STADD_Case_Contact');
        Case_Contact__c c = new Case_Contact__c(
            recordTypeId = staddRTId,
            Id = contactId
        );

        UPDATE c;
    }

    /**
     * Get related Intake__c record for a given Referral__c
     * @param referralId The ID of the Referral__c record
     * @return The ID of the related Intake__c record, or null if not found
     */
    @AuraEnabled
    public static String getRelatedIntakeId(String referralId){
        List<Intake__c> intakes = [SELECT Id FROM Intake__c WHERE Referral__c = :referralId LIMIT 1];
        if(intakes != null && intakes.size() > 0){
            return intakes[0].Id;
        }
        return null;
    }

    /**
     * Get Referral__c from an Intake__c record
     * @param intakeId The ID of the Intake__c record
     * @return The ID of the related Referral__c record, or null if not found
     */
    @AuraEnabled
    public static String getReferralIdFromIntake(String intakeId){
        List<Intake__c> intakes = [SELECT Referral__c FROM Intake__c WHERE Id = :intakeId LIMIT 1];
        if(intakes != null && intakes.size() > 0 && intakes[0].Referral__c != null){
            return intakes[0].Referral__c;
        }
        return null;
    }
  /**
     * Get related case record for a given Referral__c
     * @param referralId The ID of the Referral__c record
     * @return The ID of the related case record, or null if not found
     */
    @AuraEnabled
    public static String getRelatedCaseId(String referralId){
        List<Case> cases = [SELECT Id FROM Case WHERE Referral__c = :referralId LIMIT 1];
        if(cases != null && cases.size() > 0){
             return cases[0].Id;
        }
        return null;
    }

    /**
     * Get Referral__c from a Case record
     * @param caseId The ID of the Case record
     * @return The ID of the related Referral__c record, or null if not found
     */
    @AuraEnabled
    public static String getReferralIdFromCase(String caseId){
        List<Case> cases = [SELECT Referral__c FROM Case WHERE Id = :caseId LIMIT 1];
        if(cases != null && cases.size() > 0 && cases[0].Referral__c != null){
            return cases[0].Referral__c;
        }
        return null;
    }

    /**
     * Get Intake__c from a Case record
     * @param caseId The ID of the Case record
     * @return The ID of the related Intake__c record, or null if not found
     */
    @AuraEnabled
    public static String getIntakeIdFromCase(String caseId){
        List<Intake__c> intk = [SELECT Id FROM Intake__c WHERE case__c = :caseId LIMIT 1];
        if(intk != null && intk.size() > 0 ){
            return intk[0].Id;
        }
        return null;
    }


    /**
     * Case Team Wrapper
     */
    public class CaseTeamWrapper{
        @AuraEnabled
        public String userOrContactId{get;set;}
        @AuraEnabled
        public String userName{get;set;}
    }

    /**
     * Wrapper class for Goal Steps
     */
    public class TransitionGoalSteps{
        @AuraEnabled
        public String recordId{get;set;}
        @AuraEnabled
        public String domain{get;set;}
        @AuraEnabled
        public String title{get;set;}
        @AuraEnabled
        public String action{get;set;}
        @AuraEnabled
        public Date stepTobeCompleted{get;set;}
        @AuraEnabled
        public String stepTobeCompletedString{get;set;}
        @AuraEnabled
        public String supportedBy{get;set;}
        @AuraEnabled
        public String stage{get;set;}
        @AuraEnabled
        public String individualName{get;set;}
        @AuraEnabled
        public String caseTeamMember {get;set;}
    }


    /**
     * Wrapper class for Have's
     */
    public class PlanHaves{
        @AuraEnabled
        public String contact{get;set;}
        @AuraEnabled
        public String have{get;set;}
        @AuraEnabled
        public String details{get;set;}
        @AuraEnabled
        public String endDate{get;set;}
        @AuraEnabled
        public String transitionPlanId{get;set;}
        @AuraEnabled
        public String recordId{get;set;}
        @AuraEnabled
        public String status{get;set;}

    }

    /**
     * Wrapper class for Needs
     */
    public class PlanNeeds{
        @AuraEnabled public String contact{get;set;}
        @AuraEnabled public String need{get;set;}
        @AuraEnabled public String details{get;set;}
        @AuraEnabled public String startDate{get;set;}
        @AuraEnabled public String transitionPlanId{get;set;}
        @AuraEnabled public String recordId{get;set;}
        @AuraEnabled public String status{get;set;}
        @AuraEnabled public List<NeedSteps> needSteps{get;set;}
    }


    /**
     * Wrapper Class For Need Steps
     */
    public class NeedSteps{
        @AuraEnabled
        public String transitionNeedId{get;set;}
        @AuraEnabled
        public String recordId{get;set;}
        @AuraEnabled
        public String actionToMeetGoal{get;set;}
        @AuraEnabled
        public String stage{get;set;}
        @AuraEnabled
        public String title{get;set;}
        @AuraEnabled
        public String stepCompletedBy{get;set;}
        @AuraEnabled
        public String whoIsSupporting{get;set;}
        @AuraEnabled
        public Boolean isGoalStepEditable{get;set;}
        @AuraEnabled
        public String caseTeamMember{get;set;}
        @AuraEnabled
        public Boolean isGoalStepDeletable{get;set;}
        public NeedSteps(){
            this.isGoalStepEditable = true;
            this.isGoalStepDeletable = false;
        }
    }

    /**
     * Wrapper Class for Case Transition Plans
     */
    public class TransitionPlan{
        @AuraEnabled
        public String transitionId{get;set;}
        @AuraEnabled
        public String domain{get;set;}
        @AuraEnabled
        public String whatsImpToMe{get;set;}
        @AuraEnabled
        public String planStatus{get;set;}
        @AuraEnabled
        public String icon{get;set;}
        @AuraEnabled
        public String tabClass{get;set;}
        @AuraEnabled
        public Boolean showBadge{get;set;}
        @AuraEnabled
        public Integer sortOrder{get;set;}
    }

    /**
     * Wrapper Class for Case Service Review
     */
    public class ServiceReview{
        @AuraEnabled
        public String recordId{get;set;}
        @AuraEnabled
        public String name{get;set;}
        @AuraEnabled
        public String serviceResponse{get;set;}
        @AuraEnabled
        public String createdDate{get;set;}
        @AuraEnabled
        public String nextReviewDate{get;set;}
        @AuraEnabled
        public String status{get;set;}
        @AuraEnabled
        public String createdBy{get;set;}
        @AuraEnabled
        public String interviewDate{get;set;}
    }
}