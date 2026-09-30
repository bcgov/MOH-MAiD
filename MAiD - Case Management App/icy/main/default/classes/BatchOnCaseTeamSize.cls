/*global with sharing class BatchOnCaseTeamSize implements Database.Batchable<sObject>{

global Database.QueryLocator start(Database.BatchableContext BC){   
   // return Database.getQueryLocator('SELECT Id,ParentId FROM CaseTeamMember where CreatedDate >= LAST_N_DAYS:1');
    return Database.getQueryLocator('SELECT Id,ParentId FROM CaseTeamMember');
}
 

global void execute(Database.BatchableContext BC, List<CaseTeamMember> scope){ 
    List<CaseTeamMember> lstCaseTeamMember = (List<CaseTeamMember>)scope;
    Map<id,integer> mapCaseIdTeamSize = new Map<id,integer>();

    for(CaseTeamMember CTM:lstCaseTeamMember)
    {
        if(mapCaseIdTeamSize.Containskey(CTM.ParentId))
        {
            mapCaseIdTeamSize.put(CTM.ParentId,mapCaseIdTeamSize.get(CTM.ParentId)+1);      
        }
        else
        {
            mapCaseIdTeamSize.put(CTM.ParentId,1);      
        }
    }

    if(mapCaseIdTeamSize.size()>0)
    {
        Map<id,Case> mapCaseIdCaseTeamCount = new Map<id,Case>([Select id,Status,Case_Team_Size__c from Case where Id IN:mapCaseIdTeamSize.keyset()] );
        
        for(Id Caseid:mapCaseIdTeamSize.keyset())
        {
            if(mapCaseIdCaseTeamCount.containskey(Caseid))              
            {
                system.debug('Case Team ID :'+ Caseid);
                system.debug('Case Team Size - from field :'+ mapCaseIdCaseTeamCount.get(Caseid).Case_Team_Size__c);
                system.debug('Case TeamSize - from program :'+ mapCaseIdTeamSize.get(Caseid));
                if(mapCaseIdCaseTeamCount.get(Caseid).Case_Team_Size__c != mapCaseIdTeamSize.get(Caseid))
                {
                    mapCaseIdCaseTeamCount.get(Caseid).Case_Team_Size__c = mapCaseIdTeamSize.get(Caseid);
                }               
            }           
        }
        ProcessorControl.inContext=true;
        database.update(mapCaseIdCaseTeamCount.values(),false);
    }
    
}

global void finish(Database.BatchableContext BC){

}
}
*/
//updated logic by Sanjoy joseph per remedy ticket number 0000585342
global with sharing class BatchOnCaseTeamSize implements Database.Batchable<sObject>{

global Database.QueryLocator start(Database.BatchableContext BC){   
    return Database.getQueryLocator('SELECT id,Status,Case_Team_Size__c from Case');
}
    
global void execute(Database.BatchableContext BC, List<Case> scope){ 
    List<Case> caseList = (List<Case>)scope;
    Map<Id,Case> caseMap = new Map<Id, Case>();
    for (Case cas:caseList)
        caseMap.put(cas.Id,cas);  
    List<CaseTeamMember> teamList = new List<CaseTeamMember>([Select id,ParentId from CaseTeamMember]);
    Map<id,integer> teamsizeMap = new Map<id,integer>();
    for(CaseTeamMember CTM:teamList) {
        if(teamsizeMap.Containskey(CTM.ParentId))
            teamsizeMap.put(CTM.ParentId,teamsizeMap.get(CTM.ParentId)+1);      
        else
            teamsizeMap.put(CTM.ParentId,1);      
    }    
    for(id caseid:caseMap.keySet()) {
        if (teamsizeMap.containsKey(caseid))
            caseMap.get(caseid).Case_Team_Size__c=teamsizeMap.get(caseid);
        else
            caseMap.get(caseid).Case_Team_Size__c=null;
    }
    ProcessorControl.inContext=true;
    database.update(caseMap.values(),false);
  }
    
global void finish(Database.BatchableContext BC){
}      
    
}