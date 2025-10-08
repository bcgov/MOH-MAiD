/*
Date  : March 31, 2021
Author: Nikhil Jeenru
ticket No: ICYE-1
Description : this is used for sharing the intakes and cases with the admins and Program leaders
By Assigning the related public groups.
*/
public without sharing class ICY_UserRegistrationHandler {
     
    public static Set<String> getAllKeycloakAssignedRoles(Id userId) {
        User u = [SELECT Keycloak_Roles__c FROM User WHERE Id = :userId LIMIT 1];
        system.debug(u.Keycloak_Roles__c);
        if (String.isBlank(u.Keycloak_Roles__c)) 
            {
                return null;
            }
        return parseRoles(u.Keycloak_Roles__c);
    }


    // Parse the payload populated in the keycloakRoles
    public static Set<String> parseRoles(String keycloakRoles) {
        System.debug('Input: ' + keycloakRoles);
        Set<String> result = new Set<String>();

        if (String.isBlank(keycloakRoles)) {
            return result;
        }
        // Find all bracketed sections using a regex
        Pattern p = Pattern.compile('\\[([^\\]]+)\\]');
        Matcher m = p.matcher(keycloakRoles);

        while (m.find()) {
            String insideBrackets = m.group(1); // gets what's inside the brackets
            for (String role : insideBrackets.split(',')) {
                if (!String.isBlank(role)) {
                    result.add(role.trim());
                    System.debug('Parsed Role: ' + role.trim());
                }
            }
        }

        return result;
    }

    // Assign the Public Groups based on the matching keycloak roles.
    public static void assignRolesMatchingPublicGroupsToUser(Id userId) {
        Set<GroupMember> membersToInsert = new Set<GroupMember>();
        Set<String> userRoles = new Set<String>();
    	userRoles = getAllKeycloakAssignedRoles(userId);

    	if (userRoles != null && !userRoles.isEmpty()) {
            if (userRoles.contains('ICY_Program_Leader') || userRoles.contains('ICY_Admin')) {
        
                Set<String> groupNames = new Set<String>();
                for (String role : userRoles) {
                    if (role != 'ICY_Program_Leader' && role != 'ICY_Admin') {
                        groupNames.add(role + '_PL');
                    }
                }
                    system.debug(groupNames);

                if (!groupNames.isEmpty()) {
                    List<Group> matchingGroups = [
                        SELECT Id FROM Group
                        WHERE Type = 'Regular' AND DeveloperName IN :groupNames
                    ];

                    for (Group g : matchingGroups) {
                        membersToInsert.add(new GroupMember(GroupId = g.Id, UserOrGroupId = userId));
                    }
                }
            }
        }

        if (!membersToInsert.isEmpty()) {
            insert new List<GroupMember>(membersToInsert);
        }
    }

}