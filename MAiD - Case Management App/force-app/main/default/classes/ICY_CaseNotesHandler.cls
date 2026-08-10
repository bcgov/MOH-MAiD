public with sharing class ICY_CaseNotesHandler {
    /**
     * After-insert handler: For each newly created Case with Referral__c:
     * Update ICY_Notes__c where Referral__c IN new case referrals AND Case__c = null
     */
    public static void afterInsert(List<Case> newCases) {
        if (newCases == null || newCases.isEmpty()) return;

        // Gather keys
        Set<String> referralKeys = new Set<String>();
        Set<Id> caseIds = new Set<Id>();
        for (Case c : newCases) {
            if (c.Referral__c != null) {
                referralKeys.add((String)c.Referral__c);
            }
            if (c.Id != null) {
                caseIds.add(c.Id);
            }
        }
        if (referralKeys.isEmpty() && caseIds.isEmpty()) return;

        // 1) First set: Notes filtered by Referral__c IN :referralKeys AND Case__c = null
        List<ICY_Notes__c> notesByReferral = new List<ICY_Notes__c>();
        if (!referralKeys.isEmpty()) {
            notesByReferral = [
                SELECT Id, Case__c, Referral__c
                FROM ICY_Notes__c
                WHERE Referral__c IN :referralKeys
                  AND Case__c = NULL
                LIMIT 10000
            ];
            // For these, set Case__c to the newly created Case Id that shares the same referral.
            // Build referral -> a sample Case Id map for quick assignment.
            Map<String, Id> referralToAnyCaseId = new Map<String, Id>();
            for (Case c : newCases) {
                if (c.Referral__c != null && c.Id != null && !referralToAnyCaseId.containsKey((String)c.Referral__c)) {
                    referralToAnyCaseId.put((String)c.Referral__c, c.Id);
                }
            }
            for (ICY_Notes__c note : notesByReferral) {
                Id caseIdForReferral = referralToAnyCaseId.get(note.Referral__c);
                if (caseIdForReferral != null) {
                    note.Case__c = caseIdForReferral;
                    note.Note_Source__c='Referral';
                }
            }
        }

        // DML for the first set only (Referral-based). The Intake-based update will be handled in an Intake trigger.
        if (!notesByReferral.isEmpty()) {
            update notesByReferral;
        }
    }

    /**
     * Returns the active Program Leader email addresses for the provided Geographic Area.
     * 
     * The method finds the queue matching the Geographic Area, gets the Public Group
     * assigned to that queue, and returns the active user email addresses from that
     * Public Group.
     *
     * @param geoArea Geographic Area value from the Case.
     * @return List of active Program Leader email addresses for the matching queue Public Group.
    */
    
    public static List<String> getProgramLeaderEmailsByGeoArea(String geoArea) {
        if(String.isBlank(geoArea)) { 
            return new List<String>();
        }

         String queueName = '%' + geoArea;

        Set<Id> groupIds = new Set<Id>();
        for(GroupMember gm : [
            SELECT UserOrGroupId
            FROM GroupMember
            WHERE Group.Type = 'Queue'
            AND Group.Name LIKE :queueName
        ]) {
            groupIds.add(gm.UserOrGroupId);
        }

        if(groupIds.isEmpty()) {
             return new List<String>();
        }
        Set<String> emails = new Set<String>();
        for(User u : [
            SELECT Email, UserRoleId, UserRole.DeveloperName
            FROM User
            WHERE IsActive = true
            AND Email != null
            AND Id IN (
                SELECT UserOrGroupId
                FROM GroupMember
                WHERE GroupId IN :groupIds
            )
        ]) {
            // Exclude users assigned to the ICY role.
            Boolean hasExcludedRole =
            u.UserRoleId != null &&
            u.UserRole.DeveloperName == System.Label.ICY_User_Role;

        if (!hasExcludedRole) {
            emails.add(u.Email);
        }

        return new List<String>(emails);
    }
}
