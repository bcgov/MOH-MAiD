import { LightningElement, wire,api } from 'lwc';
//Close Modal
import { CloseActionScreenEvent } from 'lightning/actions';
//Toast Message
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
//Pagereference
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
//Apex COntroller Actions
import getCaseTransitionPlans from '@salesforce/apex/YTS_Referral_Controller.getCaseTransitionPlans';
import getTransitionSteps from '@salesforce/apex/YTS_Referral_Controller.getTransitionSteps';
//Get Object info
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
//import object schema
import STEP_OBJ from '@salesforce/schema/YTS_Goal_Steps__c';
//import object field schema
import Current_Stage__c from '@salesforce/schema/YTS_Goal_Steps__c.Current_Stage__c';

export default class YtsCasePrintPlan extends NavigationMixin(LightningElement) {
    @wire(CurrentPageReference) pageReference;
    @api recordidfromaura;
    planSelected;
    page1 = true;
    comprehensivePlan = false;
    customPlan = false;
    showSpinner = false;
    planOptions = [];
    selectedPlans = [];
    nextButtonLabel = 'Next';
    goalSteps;
    filterCriteria = [];
    selectedStepIds = [];
    defaultSortDirection = 'asc';
    sortDirection = 'asc';
    sortedBy;
    filterCriteriaOptions =[]

    stepTableColumns = [
        { label: 'Domain', fieldName: 'domain' },
        { label: 'Title', fieldName: 'title'},
        { label: 'Action to Meet Goal', fieldName: 'action', wrapText: true},
        { label: 'Current Status', fieldName: 'stage', sortable: true},
        { label: 'Step to be completed by', fieldName: 'stepTobeCompleted', type: 'date', sortable: true},
        { label: 'Who is Supporting?', fieldName: 'supportedBy'}
    ];

    /**
     * 
     * Get Record Id
     */
     get recordId(){
        if(this.recordidfromaura != undefined && this.recordidfromaura!=null){
            return this.recordidfromaura;
        }else{
            return this.pageReference.state.recordId;
        }
        
    }

    //Get Print plan options
    get printPlanOptions() {
        return [
            { label: 'Print Comprehensive Plan', value: 'Print Comprehensive Plan' },
            { label: 'Print Custom Steps', value: 'Print Custom Steps' },
        ];
    }


    //Get Picklist values from Goal Object Fields
    @wire(getObjectInfo, { objectApiName: STEP_OBJ }) stepInfo;
    
    @wire(getPicklistValues, {
        recordTypeId: '$stepInfo.data.defaultRecordTypeId',
        fieldApiName: Current_Stage__c
    }) getGoalStatusOptions({ error, data }) {
        if (data) {
            this.filterCriteriaOptions = data.values.map(element => {
                return {
                    label: `${element.label}`,
                    value: `${element.value}`
                }
            })
        } else if (error) {
            console.error('$$ Error retrieving YTS_Goal_Step__c.Current_Stage__c picklist values: ', JSON.stringify(error));
        }
    };

    closeModal(){
        this.dispatchEvent(new CloseActionScreenEvent());

        this.dispatchEvent(new CustomEvent('closemodal'));
    }

    /**
     * 
     * @param {*} event 
     */
    handleChange(event){
        if(event.target.name == 'printplan'){
            this.planSelected = event.target.value;
            if(this.planSelected == 'Print Comprehensive Plan'){
                this.comprehensivePlan = true;
                this.page1 = false;
                this.customPlan = false;
                this.nextButtonLabel = 'Print Plan'
                this.retrieveCaseTransitionPlans();
            }else if(this.planSelected == 'Print Custom Steps'){
                this.comprehensivePlan = false;
                this.sortedBy = 'stage';
                this.page1 = false;
                this.customPlan = true;
                this.nextButtonLabel = 'Print Plan'
            }
        }else if(event.target.name == 'filter'){
            this.filterCriteria = event.target.value;
            if(this.filterCriteria.length > 0){
                this.retrieveGoalSteps();
            }
        }

    }

    /**
     * 
     */
    retrieveGoalSteps(){
        this.showSpinner = true;
        getTransitionSteps({caseId: this.recordId, filterCriteria: this.filterCriteria}).then(result=>{
            this.showSpinner = false;
            console.log('$$ Result: ', result);
            if(result){
                this.goalSteps = result;
            }
        }).catch(error=>{
            this.showSpinner = false;
            console.log('$$ ERROR: ', JSON.stringify(error));
        })
    }

    /**
     * 
     */
    retrieveCaseTransitionPlans(){
        this.showSpinner = true;
        getCaseTransitionPlans({ caseId: this.recordId }).then(result => {
            this.showSpinner = false;
            if (result) {
                let sortedPlans = this.sortTransistionPlan(result);
                this.planOptions = [];
                for(let i=0; i<sortedPlans.length; i++){
                    let eachPlan = {label: '', value: '' };
                    eachPlan.label = sortedPlans[i].domain;
                    eachPlan.value = sortedPlans[i].transitionId;
                    this.planOptions.push(eachPlan);
                    this.selectedPlans.push(sortedPlans[i].transitionId);
                }
            }
        }).catch(error=>{
            this.showSpinner = false;
            console.error('$$ Error: ', error);
        })
    }

    //Sort Transition PLans
    sortTransistionPlan(data){
        const {fieldName: sortedBy, sortDirection} = {"fieldName":"sortOrder", "sortDirection":"asc"};
        const cloneData = [...data];
        cloneData.sort(this.sortBy(sortedBy, 1));
        return cloneData;
    }

    sortBy(field, reverse, primer){
        const key = primer? function(x){
            return primer(x[field]);
        }:function(x){
            return x[field];
        };
        return function(a, b){
            a = key(a);
            b = key(b);
            return reverse * ((a>b)-(b>a));
        };
    }

    /**
     * 
     * @param {*} event 
     */
    handleDomainsSelected(event){
        this.selectedPlans = event.detail.value;

    }


    /**
     * 
     * @returns 
     */
    handlePrevious(){
        if(this.page1) return;
        if(this.comprehensivePlan){
            this.comprehensivePlan = false;
            this.page1 = true;
            this.customPlan = false;
            this.nextButtonLabel = 'Next';
        }else if(this.customPlan){
            this.comprehensivePlan = false;
            this.page1 = true;
            this.customPlan = false;
            this.nextButtonLabel = 'Next';
        }
    }

    /**
     * handle Next
     */
    handleNext(){
        if(this.page1 && this.planSelected){
            if(this.planSelected == 'Print Comprehensive Plan'){
                this.comprehensivePlan = true;
                this.page1 = false;
                this.nextButtonLabel = 'Print Plan';
            }else if(this.planSelected == 'Print Custom Steps'){
                this.customPlan = true;
                this.page1 = false;
                this.nextButtonLabel = 'Print Plan';
            }
        }else if(this.comprehensivePlan){
            if(this.selectedPlans.length > 0){
                window.open('/apex/YTS_Print_Transition_Plans?c__caseId='+this.recordId+'&c__transitionIds='+this.selectedPlans, '_blank');
                this.closeModal();
            }else{
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Select atleast one row to print.',
                        variant: 'error',
                    }),
                );
            }
        }else if(this.customPlan){
            if(this.selectedStepIds.length > 0){
                window.open('/apex/YTS_Custom_Plan_Print?c__caseId='+this.recordId+'&c__transitionIds='+this.selectedStepIds+'&c__sortByField='+this.sortedBy+'&c__sortDirection='+this.sortDirection, '_blank');
                this.closeModal();
            }else{
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Select atleast one row to print.',
                        variant: 'error',
                    }),
                );
            }
        }
    }

    /**
     * 
     * @param {*} field 
     * @param {*} reverse 
     * @param {*} primer 
     * @returns 
     */
    sortBy(field, reverse, primer) {
        const key = primer
            ? function (x) {
                  return primer(x[field]);
              }
            : function (x) {
                  return x[field];
              };

        return function (a, b) {
            a = key(a);
            b = key(b);
            return reverse * ((a > b) - (b > a));
        };
    }

    /**
     * 
     * @param {*} event 
     */
    onHandleSort(event) {
        const { fieldName: sortedBy, sortDirection } = event.detail;
        const cloneData = [...this.goalSteps];

        cloneData.sort(this.sortBy(sortedBy, sortDirection === 'asc' ? 1 : -1));
        this.goalSteps = cloneData;
        this.sortDirection = sortDirection;
        this.sortedBy = sortedBy;
    }

    /**
     * 
     * @param {*} event 
     */
    getSelectedName(event){
        const selectedRows = event.detail.selectedRows;
        let selectedIds = [];
        this.selectedStepIds = [];
        for (let i = 0; i < selectedRows.length; i++) {
            console.log('$$ You selected: ' + selectedRows[i].opportunityName);
            selectedIds.push(selectedRows[i].recordId);
        }
        this.selectedStepIds = selectedIds;
        console.log('$$ seleted step ids: ', this.selectedStepIds);

    }
}