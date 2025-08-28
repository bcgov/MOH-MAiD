trigger UserPermissionsTrigger on User (after insert, after update) { 
    if (trigger.isAfter ){
        if( trigger.isInsert || trigger.isUpdate) 
        {
            UserRegistrationPermission.processPermissions(trigger.new, Trigger.oldMap, Trigger.isUpdate, Trigger.isAfter);
            //This is to replace the code added previously to userTrigger to assign PL public groups to Admin and PL
            for (User u : Trigger.new) {
                ICY_UserRegistrationHandler.assignRolesMatchingPublicGroupsToUser(u.Id);
           }
        }
    }   
}