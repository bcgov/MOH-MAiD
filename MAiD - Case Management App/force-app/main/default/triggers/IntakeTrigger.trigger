trigger IntakeTrigger on Intake__c (after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        ICY_IntakeNotesHandler.afterUpdate(Trigger.new, Trigger.oldMap);
    }
}
