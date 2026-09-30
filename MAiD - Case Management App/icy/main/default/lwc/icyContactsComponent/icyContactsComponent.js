import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { deleteRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';

//Apex Class Controllers
 import getSobjectTypeFromId from '@salesforce/apex/YTS_Notes_Documents_Controller.getSobjectTypeFromId';
import getRelatedContacts from '@salesforce/apex/YTS_Notes_Documents_Controller.getRelatedContacts';
import getReferredByContact from '@salesforce/apex/ICY_Notes_Documents_Controller.getReferredByContact';

export default class IcyContactsComponent extends NavigationMixin(LightningElement) {

    @api objectApiName;
    @api parentRecordId;
    contactId;
    deleteConfirm = false;
    @track showAddBtn = false;
    selectedConId;
    viewMode

    showSpinner = false;
    contacts;
    referredBy;
    createEdit = false;
    createNewContact = false;
    editReferredBy= false;
    sObjectType = null;

    connectedCallback() {
        this.init();
    }

    /**
     * Component Initialize
     */
init() {
    console.log('this.parentRecordId:::', JSON.stringify(this.parentRecordId));
    this.showSpinner = true;
    
    // Get the SObject type
    getSobjectTypeFromId({ recordId: this.parentRecordId }).then(sObjectType => {
        console.log('SObject Type:', sObjectType);
        
        // Fetch contacts
        return getRelatedContacts({ recordId: this.parentRecordId }).then(result => {
            this.showSpinner = false;
            if (result) {
                this.contacts = result.lstContacts;
                if (sObjectType === 'Case') {
                    console.log('in case');
                    this.showAddBtn = result.isParentCompleted;
                     console.log('Show Add Btn: ' + this.showAddBtn);
                } else {
                    console.log('not in case');
                    console.log('isParentCompleted: ' + result.isParentCompleted);
                    console.log('isNotReReferral: ' + result.isNotReReferralCon);
                    this.showAddBtn = result.isParentCompleted && result.isNotReReferralCon;
                    console.log('Show Add Btn: ' + this.showAddBtn);
                }
            }
        });
    }).catch(error => {
        this.showSpinner = false;
        console.error('Error: ', error);
    });

    getReferredByContact({recordId: this.parentRecordId}).then(result=>{
        console.log('Referred By: '+result);
        if(result) this.referredBy = result;
    }).catch(error=>{
        console.error('Error Retrieving referral Contacts: ', error);
    })
}



    /**
     * 
     * @param {*} event 
     */
    preview(event) {
        this.viewMode = true;
        this.selectedConId = event.target.dataset.id;
        this.createNewContact = true;
    }
    
    /**
     * Add Contact
     */
    addContact() {
        this.viewMode = false;
        this.createNewContact = true;
    }

    /**
     * edit case_document__c details
     * @param {*} event 
     */
    editContact(event) {
        this.viewMode = false;
        this.selectedConId = event.target.dataset.id;
        this.createNewContact = true;
    }

    editReferralReferredBy(event) {
        this.viewMode = false;
        this.selectedConId = event.target.dataset.id;
        this.editReferredBy = true;
    }

    /**
     * delete case_document__c
     * @param {*} event 
     */
    handleDelete(event) {
        console.log('$$ selected Id for Delete ', event.target.dataset.id);
        this.contactId = event.target.dataset.id;
        this.deleteConfirm = true;
    }

    /**
     * 
     */
    closeModal() {
        this.createEdit = false;
        this.documentId = null;
        this.createNewContact = false;
        this.editReferredBy= false;
        this.selectedConId = null;
        this.init();
    }

    /**
     * delete confirmation
     */
    deleteConfirmation() {
        deleteRecord(this.contactId).then(() => {
            this.contactId = null;
            this.closeConfirmation();
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Contact Deleted',
                    variant: 'success'
                })
            );
        }).catch(error => {
            console.error('$$ ERror deleting: ', error)
        })
    }

    /**
     * close confirmation modal
     */
    closeConfirmation() {
        this.deleteConfirm = false;
        this.init();
    }



}