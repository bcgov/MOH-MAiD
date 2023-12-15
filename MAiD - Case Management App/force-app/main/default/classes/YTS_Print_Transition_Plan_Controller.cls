public without sharing class YTS_Print_Transition_Plan_Controller{
    public String nameHeader{get;set;}
    public String dob{get;set;}
    public Integer age{get;set;}
    public List<YTS_Transition_SortWrapper> transitionPlans{get;set;}
    public List<YTS_Referral_Controller.TransitionGoalSteps> stepsToPrint{get;set;}
    public String navigatorName{get;set;}
    public String datePrinted{get;set;}
    public String completedWith{get;set;}

    String selectedTransitionIds = Apexpages.currentpage().getparameters().get('c__transitionIds');
    String caseId = Apexpages.currentPage().getParameters().get('c__caseId');
    String planType = Apexpages.currentPage().getParameters().get('c__planType');
    String sortDirection = Apexpages.currentPage().getParameters().get('c__sortDirection');
    String sortedBy = Apexpages.currentPage().getParameters().get('c__sortByField');


    public YTS_Print_Transition_Plan_Controller() {
        transitionPlans = new List<YTS_Transition_SortWrapper>();
        stepsToPrint = new List<YTS_Referral_Controller.TransitionGoalSteps>();
        Set<String> recordIds = new Set<String>();
        List<String> listRecIds = new List<String>();
        listRecIds = selectedTransitionIds.split(',');
        recordIds.addAll(listRecIds);

        Case c = [SELECT Id, Owner.Name, RecordType.DeveloperName, AccountId, Account.Name ,Individual_Preferred_Name__c FROM Case WHERE ID =:caseId];
        Referral__c r = [SELECT ID, Individual_Name_formula__c, Current_Age__c, Individual_Date_of_Birth__c FROM Referral__c WHERE Case__c =:caseId LIMIT 1];
        System.debug('$$ Case Record Type: '+c.RecordType.DeveloperName);

        if(c.RecordType.DeveloperName == 'ICY_Standard_Case' || c.RecordType.DeveloperName == 'ICY_Close_Case'){
            system.debug('$$ icy');
            this.completedWith = 'Completed With Owner:';
        }else{
            this.completedWith = 'Completed With Navigator:';
        }

        System.debug('$$ Completed with: '+this.completedWith);

        if(c.Individual_Preferred_Name__c == '' || c.Individual_Preferred_Name__c == null){
            this.nameHeader = c.Account.Name + ' Transition Plan';
        }else{
            this.nameHeader = c.Individual_Preferred_Name__c + ' Transition Plan';
        }

     //   this.nameHeader = c.Individual_Preferred_Name__c + ' Transition Plan';
        this.dob = YTS_Utility.dateFormat_MMMdyyyy(r.Individual_Date_of_Birth__c);
        this.age = Integer.valueOf(r.Current_Age__c);
        this.navigatorName = c.Owner.Name;
        this.datePrinted = YTS_Utility.dateFormat_MMMdyyyy(Date.today());
        if(recordIds.size() > 0){
            Id checkRec = Id.valueOf(listRecIds[0]);

            if(checkRec.getSobjectType() == Schema.YTS_Transition_Plan__c.SObjectType){
                for(YTS_Transition_Plan__c p: [SELECT Id, Transition_Domain__c, What_s_Important_to_Me__c FROM YTS_Transition_Plan__c WHERE ID IN :recordIds]){                    
                    switch on p.Transition_Domain__c {
                        when  'Relationships'{
                            transitionPlans.add(
                                new YTS_Transition_SortWrapper(
                                    1,
                                    p.Transition_Domain__c,
                                    p.What_s_Important_to_Me__c,
                                    YTS_Referral_Controller.getTransitionHaves(p.Id),
                                    YTS_Referral_Controller.getTransitionNeeds(p.Id)
                                )
                            );
                        }
                        when 'Team'{
                            transitionPlans.add(
                                new YTS_Transition_SortWrapper(
                                    2,
                                    p.Transition_Domain__c,
                                    p.What_s_Important_to_Me__c,
                                    YTS_Referral_Controller.getTransitionHaves(p.Id),
                                    YTS_Referral_Controller.getTransitionNeeds(p.Id)
                                )
                            );
                        }
                        when 'Identity, Culture and Community'{
                            transitionPlans.add(
                                new YTS_Transition_SortWrapper(
                                    3,
                                    p.Transition_Domain__c,
                                    p.What_s_Important_to_Me__c,
                                    YTS_Referral_Controller.getTransitionHaves(p.Id),
                                    YTS_Referral_Controller.getTransitionNeeds(p.Id)
                                )
                            );
                        }
                        when 'Money Management'{
                            transitionPlans.add(
                                new YTS_Transition_SortWrapper(
                                    4,
                                    p.Transition_Domain__c,
                                    p.What_s_Important_to_Me__c,
                                    YTS_Referral_Controller.getTransitionHaves(p.Id),
                                    YTS_Referral_Controller.getTransitionNeeds(p.Id)
                                )
                            );
                        }
                        when 'Physical Health'{
                            transitionPlans.add(
                                new YTS_Transition_SortWrapper(
                                    5,
                                    p.Transition_Domain__c,
                                    p.What_s_Important_to_Me__c,
                                    YTS_Referral_Controller.getTransitionHaves(p.Id),
                                    YTS_Referral_Controller.getTransitionNeeds(p.Id)
                                )
                            );
                        }
                        when 'Mental Health and Wellness'{
                            transitionPlans.add(
                                new YTS_Transition_SortWrapper(
                                    6,
                                    p.Transition_Domain__c,
                                    p.What_s_Important_to_Me__c,
                                    YTS_Referral_Controller.getTransitionHaves(p.Id),
                                    YTS_Referral_Controller.getTransitionNeeds(p.Id)
                                )
                            );
                        }
                        when 'Housing'{
                            transitionPlans.add(
                                new YTS_Transition_SortWrapper(
                                    7,
                                    p.Transition_Domain__c,
                                    p.What_s_Important_to_Me__c,
                                    YTS_Referral_Controller.getTransitionHaves(p.Id),
                                    YTS_Referral_Controller.getTransitionNeeds(p.Id)
                                )
                            );
                        }
                        when 'Job Readiness and Employment'{
                            transitionPlans.add(
                                new YTS_Transition_SortWrapper(
                                    8,
                                    p.Transition_Domain__c,
                                    p.What_s_Important_to_Me__c,
                                    YTS_Referral_Controller.getTransitionHaves(p.Id),
                                    YTS_Referral_Controller.getTransitionNeeds(p.Id)
                                )
                            );
                        }
                        when 'Education'{
                            transitionPlans.add(
                                new YTS_Transition_SortWrapper(
                                    9,
                                    p.Transition_Domain__c,
                                    p.What_s_Important_to_Me__c,
                                    YTS_Referral_Controller.getTransitionHaves(p.Id),
                                    YTS_Referral_Controller.getTransitionNeeds(p.Id)
                                )
                            );
                        }
                        when 'Life Skills'{
                            transitionPlans.add(
                                new YTS_Transition_SortWrapper(
                                    10,
                                    p.Transition_Domain__c,
                                    p.What_s_Important_to_Me__c,
                                    YTS_Referral_Controller.getTransitionHaves(p.Id),
                                    YTS_Referral_Controller.getTransitionNeeds(p.Id)
                                )
                            );
                        }
                        when else{
                            transitionPlans.add(
                                new YTS_Transition_SortWrapper(
                                    10,
                                    p.Transition_Domain__c,
                                    p.What_s_Important_to_Me__c,
                                    YTS_Referral_Controller.getTransitionHaves(p.Id),
                                    YTS_Referral_Controller.getTransitionNeeds(p.Id)
                                )
                            );
                        }
                    }
                }
                transitionPlans.sort();
            }else if(checkRec.getSobjectType() == Schema.YTS_Goal_Steps__c.SObjectType){
                List<YTS_Goal_Steps__c> querySteps = new List<YTS_Goal_Steps__c>();
                if(String.isNotBlank(sortDirection) && String.isNotBlank(sortedBy)){
                    if(sortDirection == 'asc' && sortedBy == 'stage'){
                        querySteps = [SELECT Id, Action_Goal_Description__c, Current_Stage__c, Title__c, Transition_Plan_Domain__c,
                        Step_Completed_By__c, Who_Is_Supporting_this__c FROM YTS_Goal_Steps__c WHERE ID IN :recordIds ORDER BY Current_Stage__c desc];
                    }else if(sortDirection == 'desc' && sortedBy == 'stage'){
                        querySteps = [SELECT Id, Action_Goal_Description__c, Current_Stage__c, Title__c, Transition_Plan_Domain__c,
                        Step_Completed_By__c, Who_Is_Supporting_this__c FROM YTS_Goal_Steps__c WHERE ID IN :recordIds ORDER BY Current_Stage__c asc];
                    }else if(sortDirection == 'asc' && sortedBy == 'stepTobeCompleted'){
                        querySteps = [SELECT Id, Action_Goal_Description__c, Current_Stage__c, Title__c, Transition_Plan_Domain__c,
                        Step_Completed_By__c, Who_Is_Supporting_this__c FROM YTS_Goal_Steps__c WHERE ID IN :recordIds ORDER BY Step_Completed_By__c asc];
                    }else if(sortDirection == 'desc' && sortedBy == 'stepTobeCompleted'){
                        querySteps = [SELECT Id, Action_Goal_Description__c, Current_Stage__c, Title__c, Transition_Plan_Domain__c,
                        Step_Completed_By__c, Who_Is_Supporting_this__c FROM YTS_Goal_Steps__c WHERE ID IN :recordIds ORDER BY Step_Completed_By__c desc];
                    }
                }else{
                    querySteps = [SELECT Id, Action_Goal_Description__c, Current_Stage__c, Title__c, Transition_Plan_Domain__c,
                    Step_Completed_By__c, Who_Is_Supporting_this__c FROM YTS_Goal_Steps__c WHERE ID IN :recordIds];
                }

                for(YTS_Goal_Steps__c s: querySteps){ 
                    YTS_Referral_Controller.TransitionGoalSteps g = new YTS_Referral_Controller.TransitionGoalSteps();
                    g.recordId = s.Id;
                    g.domain = s.Transition_Plan_Domain__c;
                    g.title = s.Title__c;
                    g.action = s.Action_Goal_Description__c;
                    g.stepTobeCompletedString = YTS_Utility.dateFormat_MMMdyyyy(s.Step_Completed_By__c);
                    g.supportedBy = s.Who_Is_Supporting_this__c;
                    g.stage = s.Current_Stage__c;
                    stepsToPrint.add(g);
                }
            }
        }
    }
}