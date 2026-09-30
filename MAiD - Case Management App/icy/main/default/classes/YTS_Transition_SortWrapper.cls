global with sharing class YTS_Transition_SortWrapper implements Comparable {
    public Integer sortOrder{get;set;}
    public String domain{get;set;}
    public String whatIsImpToMe{get;set;}
    public List<YTS_Referral_Controller.PlanHaves> haves{get;set;}
    public List<YTS_Referral_Controller.PlanNeeds> needs{get;set;}

    public YTS_Transition_SortWrapper(Integer sortOrder, String domain, String whatIsImpToMe, List<YTS_Referral_Controller.PlanHaves> haves, List<YTS_Referral_Controller.PlanNeeds> needs){
        this.sortOrder = sortOrder;
        this.domain = domain;
        this.whatIsImpToMe =whatIsImpToMe;
        this.haves = haves;
        this.needs = needs;
    }

    global Integer compareTo(Object compareTo){
        return Integer.valueOf(sortOrder - ((YTS_Transition_SortWrapper)compareTo).sortOrder);
    }
}