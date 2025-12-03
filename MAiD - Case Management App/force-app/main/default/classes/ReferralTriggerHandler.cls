public class ReferralTriggerHandler {

    public static void handleAfterInsertOrUpdate(List<Referral__c> referralList) {
        Set<Id> referralIds = new Set<Id>();
        Map<Id,Referral__c> personAccIdRefIdMap = new Map<Id,Referral__c>();
        for (Referral__c ref : referralList) {
            referralIds.add(ref.Id);
            if (ref.Individual__c != null)
               personAccIdRefIdMap.put(ref.Individual__c, ref);
        }

        Map<Id, Referral__c> refMap = new Map<Id, Referral__c>(
            [SELECT Id,
                    Individual_First_Name__c,
                    Individual_Last_Name__c,
                    Individual_Preferred_Name__c,
                    Individual_Date_of_Birth__c,
                    ICY_Personal_Health_Number__c,
                    ICY_Searchable_DOB__c
             FROM Referral__c
             WHERE Id IN :referralIds]
        );

        List<Referral__c> referralsToUpdate = new List<Referral__c>();
        List<Intake__c> intakesToUpdate = new List<Intake__c>();
        List<Case> casesToUpdate = new List<Case>();
         List<Account> accountsToUpdate = new List<Account>();

        // Update ICY_Searchable_DOB__c on Referral__c
        for (Referral__c ref : refMap.values()) {
            String dobString = ref.Individual_Date_of_Birth__c != null
                ? String.valueOf(ref.Individual_Date_of_Birth__c)
                : null;

            if (ref.ICY_Searchable_DOB__c != dobString) {
                ref.ICY_Searchable_DOB__c = dobString;
                referralsToUpdate.add(ref);
            }
        }

        if (!referralsToUpdate.isEmpty()) {
            update referralsToUpdate;
        }

        // Update related Intake__c fields
        List<Intake__c> intakes = [
            SELECT Id, Referral__c
            FROM Intake__c
            WHERE Referral__c IN :referralIds
        ];

        for (Intake__c inRec : intakes) {
            Referral__c ref = refMap.get(inRec.Referral__c);
            if (ref != null) {
                inRec.ICY_REF_Indi_First_Name__c         = ref.Individual_First_Name__c;
                inRec.ICY_REF_Indi_Last_Name__c          = ref.Individual_Last_Name__c;
                inRec.ICY_REF_Indi_Preferred_Name__c     = ref.Individual_Preferred_Name__c;
                inRec.ICY_REF_Indi_DOB__c                = ref.Individual_Date_of_Birth__c;
                inRec.ICY_REF_Personal_Health_Number__c  = ref.ICY_Personal_Health_Number__c;
                inRec.ICY_Searchable_DOB__c              = ref.Individual_Date_of_Birth__c != null
                                                            ? String.valueOf(ref.Individual_Date_of_Birth__c)
                                                            : null;
                intakesToUpdate.add(inRec);
            }
        }

        if (!intakesToUpdate.isEmpty()) {
            update intakesToUpdate;
        }

        // Update related Case fields
        List<Case> cases = [
            SELECT Id, Referral__c
            FROM Case
            WHERE Referral__c IN :referralIds
        ];

        for (Case cRec : cases) {
            Referral__c ref = refMap.get(cRec.Referral__c);
            if (ref != null) {
                cRec.ICY_Ref_Ind_First_Name__c         = ref.Individual_First_Name__c;
                cRec.ICY_Ref_Ind_Last_Name__c          = ref.Individual_Last_Name__c;
                cRec.ICY_Ref_Ind_Preferred_Name__c     = ref.Individual_Preferred_Name__c;
                cRec.ICY_Ref_Ind_DOB__c                = ref.Individual_Date_of_Birth__c;
                cRec.ICY_Ref_Personal_Health_Number__c = ref.ICY_Personal_Health_Number__c;
                cRec.ICY_Searchable_DOB__c             = ref.Individual_Date_of_Birth__c != null
                                                         ? String.valueOf(ref.Individual_Date_of_Birth__c)
                                                         : null;
                casesToUpdate.add(cRec);
            }
        }

        if (!casesToUpdate.isEmpty()) {
            update casesToUpdate;
        }

         // Update related person account
        List<Account> accList = [
            SELECT Id 
            FROM account
            WHERE id IN :personAccIdRefIdMap.keySet()
        ];

        for (Account accRec : accList) {
            Referral__c ref = personAccIdRefIdMap.get(accRec.Id);
            if (ref != null) {       
                accRec.Individual_Preferred_Name__pc = ref.Individual_Preferred_Name__c;   
                accountsToUpdate.add(accRec);
            }
        }

        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }
  }
}