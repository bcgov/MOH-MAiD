// BCMOHAD-29580
trigger userTrigger on User (After Insert, After Update) {

 for (User u : Trigger.new) {
        userRegistrationHandler.assignRolesMatchingPublicGroupsToUser(u.Id);
    }
}