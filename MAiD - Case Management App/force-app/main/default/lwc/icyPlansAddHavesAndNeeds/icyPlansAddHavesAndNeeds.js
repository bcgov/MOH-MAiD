import { api, LightningElement, track } from 'lwc';
import YTS_Interview_Generic_Validation_Msg from '@salesforce/label/c.YTS_Interview_Generic_Validation_Msg'
//import object schema
import HAVES_NEEDS_OBJECT from '@salesforce/schema/YTS_Haves_And_Needs__c';
import CONTACT_ORG_FIELD from '@salesforce/schema/YTS_Haves_And_Needs__c.Contact_Organization__c';
import DETAILS_FIELD from '@salesforce/schema/YTS_Haves_And_Needs__c.Details__c';
import HAVE_FIELD from '@salesforce/schema/YTS_Haves_And_Needs__c.Have__c';
import NEED_FIELD from '@salesforce/schema/YTS_Haves_And_Needs__c.Need__c';
import TRANSITION_FIELD from '@salesforce/schema/YTS_Haves_And_Needs__c.Transition_Plan__c';
import END_DATE_FIELD from '@salesforce/schema/YTS_Haves_And_Needs__c.End_Date__c';
import START_DATE_FIELD from '@salesforce/schema/YTS_Haves_And_Needs__c.Start_Date__c';
import OTHER_DESCRIPTION_FIELD from '@salesforce/schema/YTS_Haves_And_Needs__c.Have_Need_Other_Description__c'
import AGREEMENT_CAPTURED from '@salesforce/schema/YTS_Haves_And_Needs__c.ICY_Has_Agreement_Been_Captured__c';
import ID_FIELD from '@salesforce/schema/YTS_Haves_And_Needs__c.Id';
//create/Update Record
import { createRecord, updateRecord } from 'lightning/uiRecordApi';
//import Apex Controller Actions
import getHaveNeedRecord from '@salesforce/apex/YTS_Referral_Controller.getHaveNeedRecord';
//Toast Event
import { ShowToastEvent } from 'lightning/platformShowToastEvent';


export default class IcyPlansAddHavesAndNeeds extends LightningElement {
    @track haveOrNeed={
        Id: '',
        Have__c:'',
        Contact_Organization__c:'',
        Details__c:'',
        End_Date__c:'',
        Have_Need_Other_Description__c:'',
        Need__c:'',
        Start_Date__c:'',
        ICY_Has_Agreement_Been_Captured__c:false
    };
    @track havesAndNeeds;

    @api domain;
    @api transitionId;
    @api selectedHaveId;
    @api selectedNeedId;
    @api isHave = false;
    @api isNeed = false;
    showOtherSubject = false;
    haveOrNeedId;

    get haveOrNeedLabel(){
        return this.isHave?'Have':'Need';
    }

    get haveOrNeedDateLabel(){
        return this.isHave?'End Date':'Start Date';
    }

    get agreementCaptured(){
        return this.haveOrNeed.ICY_Has_Agreement_Been_Captured__c?true:false;
    }
    //Connected Callback
    connectedCallback(){
        //this.havesAndNeedsOptions();
        if(this.selectedHaveId) this.haveOrNeedId = this.selectedHaveId;
        if(this.selectedNeedId) this.haveOrNeedId = this.selectedNeedId;
        if(this.haveOrNeedId){
            getHaveNeedRecord({recordId: this.haveOrNeedId}).then(result=>{
                console.log('$$ Result edit have: ', result);
                this.haveOrNeed = result;
                if(this.isHave) this.showOtherSubject = (this.haveOrNeed.Have__c == 'Other');
                if(this.isNeed) this.showOtherSubject = (this.haveOrNeed.Need__c == 'Other');
            }).catch(error=>{
                console.error('$$ Error retrieving: ', error);
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Unable to retrieve Record. Refresh screen and try again.',
                        variant: 'error'
                    })
                );
            });
        }

    }

    //get haves or needs picklist values based on domain
    havesAndNeedsOptions(){
        console.log('$$ Domain: ', this.domain)
        if(!this.domain) return;

        switch (this.domain) {
            case 'Relationships':
                this.havesAndNeeds = [
                    {label:'Permanent family-like relationships (family friends/foster parents)' , value: 'Permanent family-like relationships (family friends/foster parents)'},
                    {label:'Supportive adults' , value: 'Supportive adults'},
                    {label:'Biological Family' , value: 'Biological Family'},
                    {label:'Extended Family' , value: 'Extended Family'},
                    {label:'Peers' , value: 'Peers'},
                    {label:'Community/Cultural Support' , value: 'Community/Cultural Support'},
                    {label:'Other' , value: 'Other'},
                ];
                break;
            case 'Team':
                this.havesAndNeeds = [
                    {label:'Family' , value: 'Family'},
                    {label:'Foster Parent' , value: 'Foster Parent'},
                    {label:'Friend' , value: 'Friend'},
                    {label:'Group Home' , value: 'Group Home'},
                    {label:'Guardian' , value: 'Guardian'},
                    {label:'Network' , value: 'Network'},
                    {label:'Nurse' , value: 'Nurse'},
                    {label:'Network' , value: 'Network'},
                    {label:'Physician' , value: 'Physician'},
                    {label:'Parent' , value: 'Parent'},
                    {label:'Teacher' , value: 'Teacher'},
                    {label:'Social Worker' , value: 'Social Worker'},
                    {label:'Trustee' , value: 'Trustee'},
                    {label:'Other' , value: 'Other'},
                ];
                break;
            case 'Identity, Culture and Community':
                this.havesAndNeeds = [
                    {label:'Community connections' , value: 'Community connections'},
                    {label:'Spiritual support' , value: 'Spiritual support'},
                    {label:'Peer/Mentorship circle' , value: 'Peer/Mentorship circle'},
                    {label:'Cultural safety agreement/plan' , value: 'Cultural safety agreement/plan'},
                    {label:'Ethnicity' , value: 'Ethnicity'},
                    {label:'Voter registration' , value: 'Voter registration'},
                    {label:'Language' , value: 'Language'},
                    {label:'Other' , value: 'Other'},
                ];
                break;
            case 'Money Management':
                this.havesAndNeeds = [
                    {label:'Bank Account' , value: 'Bank Account'},
                    {label:'Savings' , value: 'Savings'},
                    {label:'Source of Income' , value: 'Source of Income'},
                    {label:'Monthly Budget' , value: 'Monthly Budget'},
                    {label:'Money Management Skills' , value: 'Money Management Skills'},
                    {label:'Knowledge about filing Income Taxes' , value: 'Knowledge about filing Income Taxes'},
                    {label:'Reporting Income' , value: 'Reporting Income'},
                    {label:'Other' , value: 'Other'}
                ];
                break;
            case 'Physical Health':
                this.havesAndNeeds = [
                    {label:'Involved health professionals' , value: 'Involved health professionals'},
                    {label:'Health Status' , value: 'Health Status'},
                    {label:'Assessment' , value: 'Assessment'},
                    {label:'Education/understanding of physical health' , value: 'Education/understanding of physical health'},
                    {label:'Education/understanding of sexual health' , value: 'Education/understanding of sexual health'},
                    {label:'Medical equipment' , value: 'Medical equipment'},
                    {label:'Medications and other management strategies' , value: 'Medications and other management strategies'},
                    {label:'Nutrition/Diet' , value: 'Nutrition/Diet'},
                    {label:'Therapeutic needs – OT/PT/SL' , value: 'Therapeutic needs – OT/PT/SL'},
                    {label:'Traditional/alternative healing practices or therapies' , value: 'Traditional/alternative healing practices or therapies'},
                    {label:'Involvement in physical activities' , value: 'Involvement in physical activities'},
                    {label:'Medical/Dental coverage' , value: 'Medical/Dental coverage'},
                    {label:'Vision' , value: 'Vision'},
                    {label:'Other' , value: 'Other'},
                ];
                break;
            case 'Mental Health and Wellness':
                this.havesAndNeeds = [
                    {label:'Assessment/Diagnosis' , value: 'Assessment/Diagnosis'},
                    {label:'Health coverage' , value: 'Health coverage'},
                    {label:'Prescription plan' , value: 'Prescription plan'},
                    {label:'Involved health professionals' , value: 'Involved health professionals'},
                    {label:'Education/understanding of mental health' , value: 'Education/understanding of mental health'},
                    {label:'Help with substance use' , value: 'Help with substance use'},
                    {label:'Knowledge of resources' , value: 'Knowledge of resources'},
                    {label:'Self-management strategies' , value: 'Self-management strategies'},
                    {label:'Medications and other management strategies' , value: 'Medications and other management strategies'},
                    {label:'Traditional/alternative healing practices or therapies' , value: 'Traditional/alternative healing practices or therapies'},
                    {label:'Other' , value: 'Other'},
                ];
                break;
            case 'Housing':
                this.havesAndNeeds = [
                    {label:'Stable/Safe/Suitable housing' , value: 'Stable/Safe/Suitable housing'},
                    {label:'Rental references' , value: 'Rental references'},
                    {label:'Applications' , value: 'Applications'},
                    {label:'Education/understanding of rights' , value: 'Education/understanding of rights'},
                    {label:'Home furnishings/supplies' , value: 'Home furnishings/supplies'},
                    {label:'Knowledge of housing services' , value: 'Knowledge of housing services'},
                    {label:'Knowledge of resources/backup plan' , value: 'Knowledge of resources/backup plan'},
                    {label:'Other' , value: 'Other'},
                ];
                break;
            case 'Job Readiness and Employment':
                this.havesAndNeeds = [
                    {label:'Volunteer experience' , value: 'Volunteer experience'},
                    {label:'Work experience' , value: 'Work experience'},
                    {label:'Training' , value: 'Training'},
                    {label:'Certificates' , value: 'Certificates'},
                    {label:'Equipment' , value: 'Equipment'},
                    {label:'Interview skills' , value: 'Interview skills'},
                    {label:'Resume' , value: 'Resume'},
                    {label:'Interests/skills/goals' , value: 'Interests/skills/goals'},
                    {label:'Knowledge of resources' , value: 'Knowledge of resources'},
                    {label:'Other' , value: 'Other'},
                ];
                break;
            case 'Education':
                this.havesAndNeeds = [
                    {label:'High school graduation (Dogwood, Evergreen, Adult Dogwood)' , value: 'High school graduation (Dogwood, Evergreen, Adult Dogwood)'},
                    {label:'Post-Secondary Education' , value: 'Post-Secondary Education'},
                    {label:'Reading/writing skills' , value: 'Reading/writing skills'},
                    {label:'Math skills' , value: 'Math skills'},
                    {label:'Knowledge of education programs and services' , value: 'Knowledge of education programs and services'},
                    {label:'Knowledge of financial resources ' , value: 'Knowledge of financial resources '},
                    {label:'Other' , value: 'Other'},
                ];
                break;
            case 'Life Skills':
                this.havesAndNeeds = [
                    {label:'Personal Hygiene', value:'Personal Hygiene'},
                    {label:'Personal Safety', value:'Personal Safety'},
                    {label:'Social Media', value:'Social Media'},
                    {label:'Time Management', value:'Time Management'},
                    {label:'House Management', value:'House Management'},
                    {label:'Transportation', value:'Transportation'},
                    {label:'Budgeting/Finance', value:'Budgeting/Finance'},
                    {label:'Employment/Career Planning', value:'Employment/Career Planning'},
                    {label:'Access Community Resources', value:'Access Community Resources'},
                    {label:'Housing', value:'Housing'},
                    {label:'Social Skills', value:'Social Skills'},
                    {label:'Driver\’s license', value:'Driver\’s license'},
                    {label:'Personal identification', value:'Personal identification'},
                    {label:'Safe personal filing system', value:'Safe personal filing system'},
                    {label:'Other', value:'Other'},
                ];
                break;
        }
    }

    /**
     * Handle Change
     */
     handleChange(event){
         console.log('@@value',event.target.value);
        if (event.target.name) {
            switch (event.target.name) {
                case 'Have__c':
                    this.haveOrNeed.Have__c = event.target.value;
                    if(event.target.value == 'Other'){
                        this.showOtherSubject = true;
                    }else{
                        this.haveOrNeed.Have_Need_Other_Description__c = '';
                        this.showOtherSubject = false;
                    }
                    break;
                case 'Need__c':
                    this.haveOrNeed.Need__c = event.target.value;
                    if(event.target.value == 'Other'){
                        this.showOtherSubject = true;
                    }else{
                        this.haveOrNeed.Have_Need_Other_Description__c = '';
                        this.showOtherSubject = false;
                    }
                    break;
                case 'Have_Need_Other_Description__c':
                    this.haveOrNeed.Have_Need_Other_Description__c = event.target.value;
                    break;
                case 'Contact_Organization__c':
                    this.haveOrNeed.Contact_Organization__c = event.target.value;
                    break;
                case 'Details__c':
                    this.haveOrNeed.Details__c = event.target.value;
                    break;
                case 'End_Date__c':
                    this.haveOrNeed.End_Date__c = event.target.value;
                    break;
                case 'Start_Date__c':
                    this.haveOrNeed.Start_Date__c = event.target.value;
                    break;
                case 'ICY_Has_Agreement_Been_Captured__c':
                    console.log('checked',event.target.checked);
                    this.haveOrNeed.ICY_Has_Agreement_Been_Captured__c = event.target.checked;
                    break;
            }
        }
    }


    //Create or Update Record
    handleSave(){
        const fields = {};
        fields[CONTACT_ORG_FIELD.fieldApiName] = this.haveOrNeed.Contact_Organization__c;
        fields[DETAILS_FIELD.fieldApiName] = this.haveOrNeed.Details__c;
        if(this.isHave) fields[HAVE_FIELD.fieldApiName] = 'Other';
        if(this.isNeed){
            fields[NEED_FIELD.fieldApiName] = 'Other';
            fields[AGREEMENT_CAPTURED.fieldApiName]= this.haveOrNeed.ICY_Has_Agreement_Been_Captured__c;
        }
        fields[START_DATE_FIELD.fieldApiName] = this.haveOrNeed.Start_Date__c
        fields[END_DATE_FIELD.fieldApiName] = this.haveOrNeed.End_Date__c;
        fields[OTHER_DESCRIPTION_FIELD.fieldApiName] = this.haveOrNeed.Have_Need_Other_Description__c;
        let needOrHaveName = (this.haveOrNeed.Have__c? this.haveOrNeed.Have__c: this.haveOrNeed.Need__c);

        if(this.haveOrNeedId){
            fields[ID_FIELD.fieldApiName] = this.haveOrNeedId;
            const recordInput = { fields };
            updateRecord(recordInput).then(()=>{
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: needOrHaveName + ' updated Successfully',
                        variant: 'success'
                    })
                );
                const closeEvent = new CustomEvent(
                    'close'
                );
                this.dispatchEvent(closeEvent);
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
        }else{
            fields[TRANSITION_FIELD.fieldApiName] = this.transitionId
            const recordInput = {apiName: HAVES_NEEDS_OBJECT.objectApiName, fields };
            createRecord(recordInput).then(result=>{
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: needOrHaveName + ' created Successfully',
                        variant: 'success'
                    })
                );
                this.closeModal();
            }).catch(error =>{
                console.error('$$ Error creating: ', error);
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
        if(event.code == 'Escape') {
            this.closeModal();
            event.preventDefault();
            event.stopImmediatePropagation();
        }
    }

    //Validate Inputs
    validateAndSave(){
        let isValid = true;
        let inputFields = this.template.querySelectorAll('.validate');
        inputFields.forEach(inputField => {
            if (!inputField.checkValidity()) {
                inputField.reportValidity();
                isValid = false;
            }
        });
        
        if(isValid){
            this.handleSave();
        }else{
            const evt = new ShowToastEvent({
                title: YTS_Interview_Generic_Validation_Msg,
                variant: 'error'
            });
            this.dispatchEvent(evt);
        }
    }    
}