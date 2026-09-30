import { api, LightningElement, track, wire } from 'lwc';
import YTS_Interview_Generic_Validation_Msg from '@salesforce/label/c.YTS_Interview_Generic_Validation_Msg'
//create/Update Record
import { createRecord, updateRecord } from 'lightning/uiRecordApi';
//import Apex Controller Actions
import getStepRecord from '@salesforce/apex/ICY_IntegratedCarePlanCtrl.getStepRecord';
//Toast Event
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
//Get Object info
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
//import object schema
import STEP_OBJ from '@salesforce/schema/YTS_Goal_Steps__c';
//import object field schema
import Title__c from '@salesforce/schema/YTS_Goal_Steps__c.Title__c';
import Current_Stage__c from '@salesforce/schema/YTS_Goal_Steps__c.Current_Stage__c';
import Action_Goal_Description__c from '@salesforce/schema/YTS_Goal_Steps__c.Action_Goal_Description__c';
import Step_Completed_By__c from '@salesforce/schema/YTS_Goal_Steps__c.Step_Completed_By__c';
import ID_FIELD from '@salesforce/schema/YTS_Goal_Steps__c.Id';
import Transition_Needs__c from '@salesforce/schema/YTS_Goal_Steps__c.Transition_Needs__c';
import Who_Is_Supporting_this__c from '@salesforce/schema/YTS_Goal_Steps__c.Who_Is_Supporting_this__c';
import Assigned_Case_Team_Member__c from '@salesforce/schema/YTS_Goal_Steps__c.Assigned_Case_Team_Member__c';
import ICY_Case_Contact__c from '@salesforce/schema/YTS_Goal_Steps__c.ICY_Case_Contact__c';

export default class IcyPlansAddStep extends LightningElement {

    currentStageOpt = [];
    assignedTeamMemberObj;
    assignedTeamMember;

    @track step = {
        Id: '',
        Title__c: '',
        Current_Stage__c: '',
        Action_Goal_Description__c: '',
        Step_Completed_By__c: '',
        Transition_Needs__c: '',
        Who_Is_Supporting_this__c: '',
        Assigned_Case_Team_Member__c: ''
    };

    @api stepId;
    @api needId;
    @api caseId;
    @api caseTeam;

    //Get Picklist values from Goal Object Fields
    @wire(getObjectInfo, { objectApiName: STEP_OBJ }) stepInfo;

    @wire(getPicklistValues, {
        recordTypeId: '$stepInfo.data.defaultRecordTypeId',
        fieldApiName: Current_Stage__c
    }) getGoalStatusOptions({ error, data }) {
        if (data) {
            this.currentStageOpt = data.values.map(element => {
                return {
                    label: `${element.label}`,
                    value: `${element.value}`
                }
            })
        } else if (error) {
            console.error('$$ Error retrieving Gender Options: ', JSON.stringify(error));
        }
    };

    get headerTitle(){
        if(this.stepId) return 'Edit Goal';
        return 'Add New Goal'
    }

    //Connected Callback
    connectedCallback() {
        if (this.stepId) {
            getStepRecord({ recordId: this.stepId }).then(result => {
                this.step = result;
                if(result.Assigned_Case_Team_Member__c){
                    this.assignedTeamMember =  result.Assigned_Case_Team_Member__c;
                } else{
                    this.assignedTeamMember = result.ICY_Case_Contact__c ;
                }
            }).catch(error => {
                console.error('$$ Error retrieving: ', error);
            });
        }
    }

    handleAssignment(event){
        if(event.detail.value){
            if(event.detail.value.startsWith('005')){
                this.assignedTeamMemberObj = 'User';
                this.assignedTeamMember = event.detail.value;
            }else {
                this.assignedTeamMemberObj = 'Case Contact';
                this.assignedTeamMember = event.detail.value;
            }
        }
    }
    //Create or Update Record
    handleSave() {
        const fields = {};
        fields[Action_Goal_Description__c.fieldApiName] = this.step.Action_Goal_Description__c;
        fields[Current_Stage__c.fieldApiName] = this.step.Current_Stage__c;
        fields[Title__c.fieldApiName] = this.step.Title__c;
        fields[Step_Completed_By__c.fieldApiName] = this.step.Step_Completed_By__c;
        fields[Who_Is_Supporting_this__c.fieldApiName] = this.step.Who_Is_Supporting_this__c;
        if(this.assignedTeamMemberObj == 'User')
            fields[Assigned_Case_Team_Member__c.fieldApiName] = this.assignedTeamMember;
        if(this.assignedTeamMemberObj == 'Case Contact')
        fields[ICY_Case_Contact__c.fieldApiName] = this.assignedTeamMember;

        if (this.stepId) {
            fields[ID_FIELD.fieldApiName] = this.stepId;
            const recordInput = { fields };
            updateRecord(recordInput).then(() => {
                this.closeModal();
            }).catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error updating record',
                        message: error.body.message,
                        variant: 'error'
                    })
                );
            });
        } else {
            fields[Transition_Needs__c.fieldApiName] = this.needId;
            const recordInput = { apiName: STEP_OBJ.objectApiName, fields };
            createRecord(recordInput).then(result => {
                this.closeModal();
            }).catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error creating record',
                        message: error.body.message,
                        variant: 'error'
                    })
                );
            });
        }
    }

    //Close Modal
    closeModal() {
        const closeEvent = new CustomEvent(
            'close'
        );
        this.dispatchEvent(closeEvent);
    }

    //close Modal on Click on Esc
    handleKeyDown(event) {
        if (event.code == 'Escape') {
            this.closeModal();
            event.preventDefault();
            event.stopImmediatePropagation();
        }
    }

    //Validate Inputs
    validateAndSave() {
        let isValid = true;
        let inputFields = this.template.querySelectorAll('.validate');
        inputFields.forEach(inputField => {
            if (!inputField.checkValidity()) {
                inputField.reportValidity();
                isValid = false;
            } else {
                this.step[inputField.name] = inputField.value;
            }
        });

        if (isValid) {
            this.handleSave();
        } else {
            const evt = new ShowToastEvent({
                title: YTS_Interview_Generic_Validation_Msg,
                variant: 'error'
            });
            this.dispatchEvent(evt);
        }
    }
}