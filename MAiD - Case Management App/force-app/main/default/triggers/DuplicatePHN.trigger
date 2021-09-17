trigger DuplicatePHN on Case (before insert, before update) {
    DuplicatePHNHandler duplicatePHN = new DuplicatePHNHandler();
    if((Trigger.isInsert || Trigger.isUpdate) && Trigger.isBefore){
        duplicatePHN.beforeInsertUpdate(Trigger.New);
    }
}