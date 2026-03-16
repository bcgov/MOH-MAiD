import { LightningElement, wire, track,api } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
//Toast
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
//Update Contact Record TYpe
import getCurrentUserRecordTypeId from '@salesforce/apex/YTS_Referral_Controller.getCaseContactRecordTypeId';
import getRelatedIntakeId from '@salesforce/apex/YTS_Referral_Controller.getRelatedIntakeId';
import getRelatedCaseId from '@salesforce/apex/YTS_Referral_Controller.getRelatedCaseId';
import getReferralIdFromIntake from '@salesforce/apex/YTS_Referral_Controller.getReferralIdFromIntake';
import getReferralIdFromCase from '@salesforce/apex/YTS_Referral_Controller.getReferralIdFromCase';
import getIntakeIdFromCase from '@salesforce/apex/YTS_Referral_Controller.getIntakeIdFromCase';

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
       if(this.recordId && this.objectApiName == 'Referral__c'){ 
            this.referralId = this.recordId;
            // Auto-populate Intake__c field if related Intake__c record exists
            getRelatedIntakeId({ referralId: this.recordId })
                .then(result => {
                    if(result) {
                        this.IntakeId = result;
                    }
                })
                .catch(error => {
                    console.error('Error fetching related intake: ', error);
                });
            // Auto-populate Case__c field if related Case record exists
            getRelatedCaseId({ referralId: this.recordId })
                .then(result => {
                    if(result) {
                        this.caseId = result;
                    }
                })
                .catch(error => {
                    console.error('Error fetching related case: ', error);
                });
        } else if(this.recordId && this.objectApiName == 'Intake__c') {
            this.IntakeId = this.recordId;
            // Get the Referral ID from the Intake record
            getReferralIdFromIntake({ intakeId: this.recordId })
                .then(referralId => {
                    if(referralId) {
                        this.referralId = referralId;
                        // Auto-populate Case__c field if related Case record exists for this referral
                        getRelatedCaseId({ referralId: referralId })
                            .then(caseId => {
                                if(caseId) {
                                    this.caseId = caseId;
                                }
                            })
                            .catch(error => {
                                console.error('Error fetching related case: ', error);
                            });
                    }
                })
                .catch(error => {
                    console.error('Error fetching referral from intake: ', error);
                });
        } else if(this.recordId && this.objectApiName == 'Case') {
            this.caseId = this.recordId;
            // Get the Referral ID from the Case record
            getReferralIdFromCase({ caseId: this.recordId })
                .then(referralId => {
                    if(referralId) {
                      this.referralId = referralId;
                    }
                })
                .catch(error => {
                    console.error('Error fetching referral from case: ', error);
                });
            // Get the Intake ID from the Case record
            getIntakeIdFromCase({ caseId: this.recordId })
                .then(intakeId => {
                    if(intakeId) {
                        this.IntakeId = intakeId;
                    }
                })
                .catch(error => {
                    console.error('Error fetching intake from case: ', error);
                });
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
}