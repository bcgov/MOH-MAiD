global class SchedulableCaseTeamBatchJob implements Schedulable 
{
    global static void execute(SchedulableContext sc) 
    {
      BatchOnCaseTeamSize Job = new BatchOnCaseTeamSize();  
      database.executebatch(Job, 200); 
    }
}