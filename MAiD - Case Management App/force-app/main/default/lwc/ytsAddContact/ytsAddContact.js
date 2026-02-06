import { LightningElement, wire, track,api } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
//Toast
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
//Update Contact Record TYpe
import getCurrentUserRecordTypeId from '@salesforce/apex/YTS_Referral_Controller.getCaseContactRecordTypeId';

export default class YtsAddContact extends LightningElement {
    @wire(CurrentPageReference) pageReference;
    @api recordId;
    @api objectApiName;
    @api contactRecId;
    @api viewMode = false;
    @api recordTypeId;


    referralId ='';
    IntakeId='';
    caseId='';
    activeSections = ['A','B','C'];
    readOnly = false;
    showSpinner = false;
    isIntake = false;
    isCase = false
    isReferral = false;
    disabled = false;

    @wire(getCurrentUserRecordTypeId) getCurrentUserRecordTypeId({error, data}){
        console.log(data);
        if(data){
            this.recordTypeId = data
        }else if(error){
            console.error('$$ Error getting case contact recordtypeid '+error);
        }
    }

    get heading(){
        if(this.contactRecId){
            return 'Add New Contact'
        }else{
            if(this.viewMode) return Contact;
            else return 'Edit Contact';
        }
    }

    isInputValid() {
        let isValid = true;
        let inputFields = this.template.querySelectorAll('.validate');
        inputFields.forEach(inputField => {
            if (!inputField.checkValidity()) {
                inputField.reportValidity();
                isValid = false;
            }
        });
        return isValid;
    }


    connectedCallback(){
       this.showSpinner = true;
       // Only set parent record IDs when creating a new contact (contactRecId is empty)
       if (!this.contactRecId) {
           if(this.recordId && this.objectApiName == 'Referral__c'){
                this.referralId = this.recordId;
           }else if(this.recordId && this.objectApiName == 'Intake__c')
                this.IntakeId = this.recordId;
            else if(this.recordId && this.objectApiName == 'Case')
                this.caseId = this.recordId;
       }
       this.showSpinner = false;

    }

    closeModal() {
        const closeEvent = new CustomEvent(
            'close',
            { detail : this.contactRecId }
        );
        this.dispatchEvent(closeEvent);
    }

    handleReset(event) {
        const inputFields = this.template.querySelectorAll(
            'lightning-input-field'
        );
        if (inputFields) {
            inputFields.forEach(field => {
                field.reset();
            });
        }
        this.dispatchEvent(new CustomEvent('close'));
     }

    disableButton(){
        this.disabled =  true;
    }

     handleRecordCreation(event) {
        this.disableButton();
        console.log('$$ E: ', JSON.stringify(event.detail));
        if (!this.isInputValid()) {
            const evt = new ShowToastEvent({
                title: 'Missing Required Fields',
                variant: 'error'
            });
            this.dispatchEvent(evt);
            this.disabled = false;
            return;
        }

        this.disabled = false;
        this.dispatchEvent(new CustomEvent('close',{ detail : event.detail.id }));
     }

    handleError(event) {
        this.disabled = false;
        console.error('Form Error:', JSON.stringify(event.detail));
        const evt = new ShowToastEvent({
            title: 'Error Saving Record',
            message: 'An error occurred while saving the record. Please try again.',
            variant: 'error'
        });
        this.dispatchEvent(evt);
    }
}