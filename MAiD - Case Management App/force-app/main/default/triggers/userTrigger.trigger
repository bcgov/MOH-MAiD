// BCMOHAD-29580
trigger userTrigger on User (After Insert, After Update) {

 for (User u : Trigger.new) {
        ICY_UserRegistrationHandler.assignRolesMatchingPublicGroupsToUser(u.Id);
    }
}