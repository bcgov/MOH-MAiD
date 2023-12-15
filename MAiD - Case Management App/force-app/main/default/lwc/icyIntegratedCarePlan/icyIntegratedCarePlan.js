import { LightningElement, api, track } from 'lwc';
//Apex COntroller Actions
import getCaseTransitionPlans from '@salesforce/apex/ICY_IntegratedCarePlanCtrl.getCaseTransitionPlans';
import getTransitionHaves from '@salesforce/apex/ICY_IntegratedCarePlanCtrl.getTransitionHaves';
import getTransitionNeeds from '@salesforce/apex/ICY_IntegratedCarePlanCtrl.getTransitionNeeds';
import getCaseTeam from '@salesforce/apex/ICY_IntegratedCarePlanCtrl.getCaseTeam';
import getUserProfileName from '@salesforce/apex/YTS_Notes_Documents_Controller.getUserProfileName';
import getCaseStatus from '@salesforce/apex/ICY_IntegratedCarePlanCtrl.getCaseStatus';
import checkIfUserIsCaseMember from '@salesforce/apex/ICY_IntegratedCarePlanCtrl.isLoggedInUserCaseMember';
//DML Record
import { updateRecord, deleteRecord } from 'lightning/uiRecordApi';
//Transition Plan Fields Schema
import WHAT_S_IMPORTANT_FIELD from '@salesforce/schema/YTS_Transition_Plan__c.What_s_Important_to_Me__c';
import ID_FIELD from '@salesforce/schema/YTS_Transition_Plan__c.Id';
//Toast
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
export default class IcyIntegratedCarePlan extends LightningElement {
    activeSections = ['A', 'B', 'C'];
    activeNeedSections = [];
    activeHaveSections = [];
    haveUtilityIcon = 'utility:expand_all';
    haveUtilityTitle = 'Expand Haves';
    needUtilityIcon = 'utility:expand_all';
    needUtilityTitle = 'Expand Needs';
    defaultSortDirection = 'asc';
    sortDirection = 'asc';
    sortedBy;
    columns = [
        { label: 'Step', fieldName: 'title',wrapText: true },
        { label: 'Progress Towards Goal', fieldName: 'actionToMeetGoal', wrapText: true },
        { label: 'Current Status', fieldName: 'stage' },
        { label: 'Target Date', fieldName: 'stepCompletedBy' }, //Josh
        { label: 'Who is Supporting this?', fieldName: 'whoIsSupporting' },
        { label: 'Assigned Case Team Member', fieldName: 'caseTeamMember' },
        {
            type: 'action',
            typeAttributes: { rowActions: this.getRowActions }
        }
    ];

    readOnlyColumns = [
        { label: 'Step', fieldName: 'title',wrapText: true },
        { label: 'Progress Towards Goal', fieldName: 'actionToMeetGoal', wrapText: true },
        { label: 'Current Status', fieldName: 'stage' },
        { label: 'Target Date', fieldName: 'stepCompletedBy', type: 'date' },
        { label: 'Who is Supporting this?', fieldName: 'whoIsSupporting' },
        { label: 'Assigned Case Team Member', fieldName: 'caseTeamMember' },

    ];

    activeSectionsMessage = '';
    richtext;
    @api caseId;
    @track transitionPlans;
    @track listOfHaves;
    @track listOfNeeds;
    @track caseTeam;

    domainHeader;
    domain;
    whatsImpToMe;
    showSpinner = false;
    currentSelectedTab;
    showSave = false;

    selectedHaveId;
    selectedNeedId;
    add = false;
    addStep = false;
    isHave = false;
    isNeed = false;
    selectedStepId;
    characterLength;
    isCaseClosed = false;
    isReadOnly = false;
    createAccess = false;
    editAccess = false;
    whatsImpToMeReadOnly = true;


    showConfirmation = false;
    deleteConfirmationText;
    recordIdToDelete;
    deleteAccess = false;

    //Connected Callback
    connectedCallback() {
        this.init();
        this.getUserProfile();
        this.getCaseTeamMembers();
    }

    //Initialize
    init() {
        this.showSpinner = true;
        this.showSave = false;
        getCaseTransitionPlans({ caseId: this.caseId }).then(result => {
            if (result) {

                this.transitionPlans = this.sortTransistionPlan(result);
                console.log('Dataa' + JSON.stringify(this.transitionPlans));
                if (!this.currentSelectedTab) {
                    this.currentSelectedTab = this.transitionPlans[0].transitionId;
                    this.domainHeader = this.transitionPlans[0].domain;
                    this.domain = this.transitionPlans[0].domain;
                    if (this.transitionPlans[0].hasOwnProperty('whatsImpToMe')) {
                        this.whatsImpToMe = this.transitionPlans[0].whatsImpToMe;
                        this.characterLength = 2000 - this.whatsImpToMe.length;
                    } else {
                        this.whatsImpToMe = '';
                        this.characterLength = 2000;
                    }
                } else {
                    for (let i = 0; i < this.transitionPlans.length; i++) {
                        if (this.currentSelectedTab == this.transitionPlans[i].transitionId) {
                            this.currentSelectedTab = this.transitionPlans[i].transitionId;
                            this.domainHeader = this.transitionPlans[i].domain;
                            this.domain = this.transitionPlans[i].domain;
                            this.transitionPlans[i].tabClass = 'slds-vertical-tabs__nav-item slds-is-active';
                            if (this.transitionPlans[i].hasOwnProperty('whatsImpToMe')) {
                                this.whatsImpToMe = this.transitionPlans[i].whatsImpToMe;
                                this.characterLength = 2000 - this.whatsImpToMe.length;
                            } else {
                                this.whatsImpToMe = '';
                                this.characterLength = 2000;
                            }
                        } else {
                            this.transitionPlans[i].tabClass = 'slds-vertical-tabs__nav-item';
                        }
                    }
                }
                this.getCaseTransitionHaves();
                this.getCaseTransitionNeeds();
            }
            return getCaseStatus({ caseId: this.caseId });
        }).then(result => {
            if (result) {
                if (result == 'Closed')
                    this.isCaseClosed = true;
            }
            this.isReadOnly = this.isCaseClosed; //Read-Only Mode if case closed //true;
            this.whatsImpToMeReadOnly = this.isReadOnly; //true;
            if (!this.isCaseClosed) {
                this.createAccess = true;
                this.editAccess = true; //false;
                this.whatsImpToMeReadOnly = false; //true;
            }
            return checkIfUserIsCaseMember({ caseId: this.caseId });
        }).then(result => {
            if(result){
                this.isReadOnly=true;
                this.createAccess=false;
                this.editAccess = false;
                this.whatsImpToMeReadOnly = true;
             }
            this.showSpinner = false;

        }).catch(error => {
            this.showSpinner = false;
            console.error('$$ Error, ', JSON.stringify(error));
        });
    }

    //Retrieve Case Team Members Assocaited with the case
    getCaseTeamMembers() {
        this.showSpinner = true;
        getCaseTeam({ caseId: this.caseId }).then(response => {
            if (response) {
                this.caseTeam = [];
                for (let i = 0; i < response.length; i++) {
                    let obj = {};
                    obj.label = response[i].userName;
                    obj.value = response[i].userOrContactId;
                    this.caseTeam.push(obj);
                }
            }
            this.showSpinner = false;
        }).catch(error => {
            this.showSpinner = false;
            console.error('$$ Error Retrieving case Team members, ', JSON.stringify(error));
        })
    }

    //get Current User Profile
    getUserProfile() {
        getUserProfileName().then(result => {
            if (result == 'System Administrator') this.deleteAccess = true;

        }).catch(error => {
            console.log('$$ Unable to retrieve User Profile: ', error);
            this.deleteAccess = false;
        })
    }

    getRowActions(row, doneCallback) {
        const actions = [];
        if (row.isGoalStepEditable) {
            actions.push({
                'label': 'Edit',
                'iconName': 'utility:edit',
                'name': 'edit'
            });
        }
        if (row.isGoalStepDeletable) {
            actions.push({
                'label': 'Delete',
                'iconName': 'utility:delete',
                'name': 'delete'
            });
        }
        // simulate a trip to the server
        setTimeout(() => {
            doneCallback(actions);
        }, 200);

    }

    //Sort Transition PLans
    sortTransistionPlan(data) {
        const { fieldName: sortedBy, sortDirection } = { "fieldName": "sortOrder", "sortDirection": "asc" };
        const cloneData = [...data];
        cloneData.sort(this.sortBy(sortedBy, 1));
        return cloneData;
    }

    sortBy(field, reverse, primer) {
        const key = primer ? function (x) {
            return primer(x[field]);
        } : function (x) {
            return x[field];
        };
        return function (a, b) {
            a = key(a);
            b = key(b);
            return reverse * ((a > b) - (b > a));
        };
    }

    //Handle Tab Change
    handleTabChange(event) {
        event.preventDefault();
        this.resetTabToggle();
        let selectedTab = event.target.dataset.recordId;
        if (selectedTab) {
            this.showSpinner = true;
            this.activeSections = ['A', 'B', 'C'];
            //change tab
            for (let i = 0; i < this.transitionPlans.length; i++) {
                if (this.transitionPlans[i].transitionId == selectedTab) {
                    console.log(this.transitionPlans[i])
                    this.transitionPlans[i].tabClass = 'slds-vertical-tabs__nav-item slds-is-active';
                    this.domainHeader = this.transitionPlans[i].domain;
                    this.domain = this.transitionPlans[i].domain;
                    this.whatsImpToMe = this.transitionPlans[i].whatsImpToMe ? this.transitionPlans[i].whatsImpToMe : '';
                    this.characterLength = 2000 - this.whatsImpToMe.length;
                    this.currentSelectedTab = selectedTab;
                    this.getCaseTransitionHaves();
                    this.getCaseTransitionNeeds();
                } else {
                    this.transitionPlans[i].tabClass = 'slds-vertical-tabs__nav-item';
                }
            }
        }
        this.showSave = false;
        this.showSpinner = false;
    }

    //reset toggles
    resetTabToggle() {
        this.activeNeedSections = [];
        this.activeHaveSections = [];
        this.haveUtilityIcon = 'utility:expand_all';
        this.haveUtilityTitle = 'Expand Haves';
        this.needUtilityIcon = 'utility:expand_all';
        this.needUtilityTitle = 'Expand Needs';
    }

    //To Update transition plan field What_s_Important_to_Me__c
    handleUpdateTransitionPlan() {
        if (this.whatsImpToMe) {
            if (this.whatsImpToMe.length > 2000) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error Saving',
                        message: 'Maximum number of characters allowed are 2000. ',
                        variant: 'error',
                    }),
                );
                return;
            }
            this.showSpinner = true;
            const fields = {};
            fields[ID_FIELD.fieldApiName] = this.currentSelectedTab;
            fields[WHAT_S_IMPORTANT_FIELD.fieldApiName] = this.whatsImpToMe;
            const recordInput = { fields };
            //Update Record
            updateRecord(recordInput).then(() => {
                this.showSpinner = false;
                console.log('$$ Updated successfully');
                this.showSave = false;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Record Updated',
                        variant: 'success',
                    }),
                );
                this.init();
                this.showSave = false;
            }).catch(error => {
                this.showSpinner = false;
                console.error('$$ Error saving What_s_Important_to_Me__c: ', error);
            });
        }
    }

    //Retrieve Transition Plan Haves and Needs when clicked on "What I have" or "What I need" Accordian
    handleMainSectionToggle(event) {
        const openSections = event.detail.openSections;
        if (openSections.length > 0 && openSections.includes('B')) {
            this.getCaseTransitionHaves();
        } else if (openSections.length > 0 && openSections.includes('C')) {
            this.getCaseTransitionNeeds();
        }
    }

    //Need
    handleNeedToggle(event) {
        const openSections = event.detail.openSections;
    }

    //Retrive Transition Haves
    getCaseTransitionHaves() {
        this.showSpinner = true;
        getTransitionHaves({ transitionPlanId: this.currentSelectedTab }).then(result => {
            this.showSpinner = false;
            if (result && result.length > 0) {
                this.listOfHaves = [];
                this.listOfHaves = result;
            }
            else
                this.listOfHaves = null;
        }).catch(err => {
            this.showSpinner = false;
            console.error('Error: ' + JSON.stringify(err));
        })
    }

    //Retrieve Transition Needs
    getCaseTransitionNeeds() {
        this.showSpinner = true;
        getTransitionNeeds({ transitionPlanId: this.currentSelectedTab }).then(result => {
            this.showSpinner = false;
            if (result && result.length > 0) {
                this.listOfNeeds = [];
                this.listOfNeeds = result;
                console.log('@@ all needs result',result);
                console.log('@@ all needs',this.listOfNeeds[0]);

            }
            else
                this.listOfNeeds = null;
        }).catch(err => {
            this.showSpinner = false;
            console.error('Error: ' + JSON.stringify(err));
        })
    }

    //Toggle Have section
    expandAllHaves() {
        if (this.haveUtilityIcon == 'utility:expand_all') {
            this.haveUtilityIcon = 'utility:collapse_all';
            this.haveUtilityTitle = 'Collapse Haves';
            this.activeHaveSections = [];
            if (this.listOfHaves.length > 0) {
                this.listOfHaves.forEach(element => {
                    this.activeHaveSections.push(element.recordId);
                });
            }
        }
        else if (this.haveUtilityIcon == 'utility:collapse_all') {
            this.haveUtilityIcon = 'utility:expand_all';
            this.haveUtilityTitle = 'Expand Haves';
            this.activeHaveSections = [];
        }
    }

    //Toggle Need section
    expandAllNeeds() {
        if (this.needUtilityIcon == 'utility:expand_all') {
            this.needUtilityIcon = 'utility:collapse_all';
            this.needUtilityTitle = 'Collapse Needs';
            this.activeNeedSections = [];

            if (this.listOfNeeds.length > 0) {
                this.listOfNeeds.forEach(element => {
                    console.log('AllNeeds',element);
                    this.activeNeedSections.push(element.recordId);
                });
            }
        }
        else if (this.needUtilityIcon == 'utility:collapse_all') {
            this.needUtilityIcon = 'utility:expand_all';
            this.needUtilityTitle = 'Expand Needs';
            this.activeNeedSections = [];
        }
    }

    //Add a New Have
    addNewHave(event) {
        console.log('$$ Domain: ', this.domain)
        this.add = true;
        this.isHave = true;
        this.isNeed = false;
    }

    //Add a New Need
    addNewNeed(event) {
        this.add = true;
        this.isHave = false;
        this.isNeed = true;
    }

    addNewStep(event) {
        this.addStep = true;
        this.selectedNeedId = event.target.dataset.recordId;
    }

    //close Modal
    closeModal() {
        this.add = false;
        this.selectedHaveId = null;
        this.selectedNeedId = null;
        this.selectedStepId = null;
        if (this.recordIdToDelete) {
            this.getCaseTransitionHaves();
            this.getCaseTransitionNeeds();
            this.recordIdToDelete = null;
        }
        this.recordIdToDelete = null;

        if (this.isHave) this.getCaseTransitionHaves();
        if (this.isNeed || this.addStep) this.getCaseTransitionNeeds();     //refresh needs section after need update/goal or step create/update
        this.addStep = false;
        this.isHave = false;
        this.isNeed = false;
        this.showConfirmation = false;
    }

    //Edit Have Record
    editHave(event) {
        console.log('$$ selected Have Record: ' + event.target.dataset.recordId);
        this.selectedHaveId = event.target.dataset.recordId;
        if (this.selectedHaveId) {
            this.add = true;
            this.isNeed = false;
            this.isHave = true;
        }
    }

    //Edit Need Record
    editNeed(event) {
        console.log('$$ selected Need Record: ' + event.target.dataset.recordId);
        this.selectedNeedId = event.target.dataset.recordId;
        if (this.selectedNeedId) {
            this.add = true;
            this.isNeed = true;
            this.isHave = false;
        }
    }

    //Delete Have, Need, Step Record
    deleteRecord(event) {
        console.log('$$ Selected Record Id To Delete: ' + event.target.dataset.recordId);
        this.recordIdToDelete = event.target.dataset.recordId
        this.showConfirmation = true;
    }

    confirmDelete() {
        deleteRecord(this.recordIdToDelete).then(() => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Record Deleted Successfully',
                    variant: 'success'
                })
            )
            this.closeModal();
        }).catch(error => {
            this.closeModal();
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error deleting record',
                    message: error.body.message,
                    variant: 'error'
                })
            )
        })
    }

    handleChange(event) {
        this.whatsImpToMe = event.target.value;
        this.characterLength = 2000 - this.whatsImpToMe.length;
        this.showSave = true;
    }

    handleClick() {
        this.showSave = false;
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        switch (actionName) {
            case 'edit':
                this.selectedStepId = event.detail.row.recordId;
                if (this.selectedStepId) this.addStep = true;
                break;
            case 'delete':
                this.recordIdToDelete = event.detail.row.recordId;
                if (this.recordIdToDelete) this.showConfirmation = true;
                break;
        }
    }
}