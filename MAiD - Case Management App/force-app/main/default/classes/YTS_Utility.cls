public with sharing class YTS_Utility {
    /**
     *
     */
    public static String getRecordTypeIdByDeveloperName(String objectApi, String recordTypeDeveloperName){
        if(String.isNotBlank(objectApi) && String.isNotBlank(recordTypeDeveloperName)){
            return Schema.getGlobalDescribe().get(objectApi).getDescribe().getRecordTypeInfosByDeveloperName().get(recordTypeDeveloperName).getRecordTypeId();
        }
        return null;
    }

    /**
     *
     */
    public static Map<String, String> getPicklistValues(String objectApi, String fieldApi){
        Map<String, String> result = new Map<String, String>();
        if(String.isNotBlank(objectApi) && String.isNotBlank((fieldApi))){
            Schema.SObjectType targetType = Schema.getGlobalDescribe().get(objectApi);//From the Object Api name retrieving the SObject
            Sobject Object_name = targetType.newSObject();
            Schema.sObjectType sobject_type = Object_name.getSObjectType(); //grab the sobject that was passed
            Schema.DescribeSObjectResult sobject_describe = sobject_type.getDescribe(); //describe the sobject
            Map<String, Schema.SObjectField> field_map = sobject_describe.fields.getMap(); //get a map of fields for the passed sobject
            List<Schema.PicklistEntry> pick_list_values = field_map.get(fieldApi).getDescribe().getPickListValues(); //grab the list of picklist values for the passed field on the sobject
            for (Schema.PicklistEntry a : pick_list_values) { //for all values in the picklist list
                result.put(a.getValue(), a.getLabel());//add the value and label  to our final Map
            }
        }
        return result;
    }

    /**
     * converts date time value to "Thu, Nov 4, 2021" format
     */
    public static String dateFormat_eeeeMMMdyyyy(DateTime dt){
        return dt.format('EEE, MMM d, yyyy');
    }

    /**
     * converts date time value to "Nov 4, 2021" format
     */
    public static String dateFormat_MMMdyyyy(Date dt){
        if(dt != null) return DateTime.newInstance(dt.year(),dt.month(),dt.day()).format('MMM d, yyyy');
        return null;
    }

    /**
     * converts date time value to "Thu, Nov 4, 2021" format
     */
    public static String dateFormat_eeeeMMMdyyyy(Date dt){
        if(dt != null) return DateTime.newInstance(dt.year(),dt.month(),dt.day()).format('EEE, MMM d, yyyy');
        return null;
    }

    /**
     * converts date time value to "Nov 4, 2021" format
     */
    public static String dateFormat_MMMdyyyy(DateTime dt){
        if(dt != null) return dt.format('MMM d, yyyy');
        return null;
    }

    /**
     * Converts date to 'YYYY-MM-DD' Format
     */
    public static String dateFormat_yyyy_mm_dd(Date dt){
        if(dt != null ) return dt.year() +'-'+dt.month()+'-'+dt.day();
        return null;
    }

    /**
     * converts date time value to "January 15, 2024 4:32 pm" format
     */
    public static String dateFormat_MMMdyyyykma(DateTime dt){
        return dt.format('MMMMM d, yyyy k:m a').replace('AM', 'am').replace('PM', 'pm');
    }

    /**
     * Retrive org wide email address Id
     */
    public static Id getICYOrgWideEmailAddressId(){
        List<OrgWideEmailAddress> addresses = [select id, Address, DisplayName from OrgWideEmailAddress WHERE DisplayName='Integrate Support ' LIMIT 1];
        Id orgwideEmailId;
        if(addresses.size() > 0){
            orgwideEmailId = addresses[0].Id;
        }
        return orgwideEmailId;
    }

//lookup in Role for specific profile
public static Boolean lookupRole(String sProfile) {

    String roleId = System.userInfo.getUserRoleId();
    if (roleId !=null){
        String usrRole = [select name from UserRole
                        where id =: roleId ].name;
        // Check if the input string and keyword are not null
        if (usrRole  != null && sProfile != null) {
            // Convert both the input string and keyword to lowercase for case-insensitive comparison
            String lowerInput = usrRole.toLowerCase();
            String lowerKeyword = sProfile.toLowerCase();

            // Check if the lowercase input string contains the lowercase keyword
            if (lowerInput.contains(lowerKeyword)) {
                return true;
            }
        }
        return false;
    }
    return false;
   }

//lookup top parent Role in hierarchy
public static Boolean isTopRoleICY() {
    Map<String, String> mapRole = new Map<String, String>();

    UserRole topRoleId = [select id from UserRole
                          where name='ICY'];

    // get List of UserRole
    List<UserRole> roleList = [select Id,ParentRoleId From UserRole];

    //put all roles and parent in  map
    for(Integer iX=0; iX < roleList.size(); iX++)
      mapRole.put(roleList[iX].Id,roleList[iX].ParentRoleId);

    String parentRole;
    String userRoleId = System.userInfo.getUserRoleId();
    for(Integer iX=0; iX < roleList.size(); iX++)
    {   parentRole=mapRole.get(userRoleId);
        if (parentRole== null)
          break;
        else
          userRoleId=parentRole;
    }

    if (userRoleId==topRoleId.Id ){
        return true;
    }

    return false;

}
}