public without sharing  class ICY_AlertBannerCtrl {
    @AuraEnabled(cacheable=true)
    public static SObject fetchBannerDetails(String strRecId, String strSobject) {
        sObject sobj;
        if(String.isNotBlank(strRecId) && String.isNotBlank(strSobject)){
            String strQuery;
            if(strSobject == 'Referral__c'){
                strQuery = 'SELECT ICY_Alert_Banner_Text__c,ICY_Show_Banner__c FROM Referral__c WHERE ID =:strRecId LIMIT 1';
            } else if (strSobject == 'Intake__c') {
               strQuery = 'SELECT  Referral__r.ICY_Alert_Banner_Text__c,Referral__c,Referral__r.ICY_Show_Banner__c FROM Intake__c WHERE ID =:strRecId LIMIT 1'; 
            } else if (strSobject == 'Case') {
               strQuery = 'SELECT ICY_Alert_Banner_Text__c,ICY_Show_Banner__c FROM Referral__c WHERE Case__c =:strRecId LIMIT 1'; 
            }
            for(sObject obj: Database.query(strQuery)){
                Id currentUser = userInfo.getuserId();
                Id currentUserProfileId = userInfo.getProfileId();
                String profileName = [Select id, Name from profile where Id=:currentUserProfileId].Name;
                if(strSobject == 'Intake__c'){
                    Intake__c intake = (Intake__c) obj;
                     ((Intake__c) obj).Referral__r.ICY_Show_Banner__c = intake.Referral__r.ICY_Show_Banner__c;
                      sobj = obj;
                 }else{
                    Referral__c ref = (Referral__c) obj;
                     ((Referral__c) obj).ICY_Show_Banner__c = ref.ICY_Show_Banner__c; 
                      sobj = obj;
                 }
                }
              
                }
                return sobj;
            }
        
    @AuraEnabled
    public static String UpdateBannerDetails(String strRecId, String strSobject, String strBannerMSg) {
        if(String.isNotBlank(strRecId) && String.isNotBlank(strSobject)){
            Referral__c objRec = new Referral__c();
            objRec.ICY_Alert_Banner_Text__c = strBannerMSg;
            objRec.ICY_Show_Banner__c = true;
            
            if(strSobject == 'Referral__c'){
                objRec.Id = strRecId;
            } else if (strSobject == 'Intake__c') {
                Intake__c objInTake = [SELECT Referral__c FROM Intake__c WHERE ID =:strRecId LIMIT 1];
                if(objInTake != null && String.isNotBlank(objInTake.Referral__c)) {
                    objRec.Id = objInTake.Referral__c;  
                }
            } else if (strSobject == 'Case') {
                objRec.Id = [SELECT Id FROM Referral__c WHERE Case__c =:strRecId LIMIT 1].id;
            }
            
            if(objRec.Id != null) {
                Update objRec;
                return 'Banner Alert Updated';
            }
        }
        return null;
    }
    
    @AuraEnabled
    public static String disableBannerAlert(String strRecId, String strSobject) {
        if(String.isNotBlank(strRecId) && String.isNotBlank(strSobject)){
            Referral__c objRec = new Referral__c();
            objRec.ICY_Show_Banner__c = false;
            
            if(strSobject == 'Referral__c'){
                objRec.Id = strRecId;
            } else if (strSobject == 'Intake__c') {
                Intake__c objInTake = [SELECT Referral__c FROM Intake__c WHERE ID =:strRecId LIMIT 1];
                if(objInTake != null && String.isNotBlank(objInTake.Referral__c)) {
                    objRec.Id = objInTake.Referral__c;  
                }
            } else if (strSobject == 'Case') {
                objRec.Id = [SELECT Id FROM Referral__c WHERE Case__c =:strRecId AND ICY_Show_Banner__c = true LIMIT 1].id;
                if(objRec.Id == null)
                    return 'Banner Alert Updated';
            }
            
            if(objRec.Id != null ) {
                Update objRec;
                return 'Banner Alert Updated';
            }
        }
        return null;
    }
    @TestVisible
    private static Set<Id> getProgramLeaders(String geoLocation){
        Set<Id> userid = new Set<Id>();
        For(User u: [SELECT Id,Name, email FROM User WHERE userrole.Name like'%Leader' AND isActive = true]){
            userid.add(u.Id);
        }
        
        return userid;
    }
    @TestVisible
	Private static set<Id> getCaseTeamMembers(String refId){
        Set<Id> userIds= new Set<id>();
        if(String.isNotBlank(refId)){
            for(Case_Member__c cm: [Select Id, ICY_User__c from Case_Member__c where Referral__c=:refId]){
                userIds.add(cm.ICY_User__c);
            }
        }
        return userIds;
    }
    
}