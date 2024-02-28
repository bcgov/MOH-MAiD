import { LightningElement, wire, api, track } from 'lwc';
 import CATEGORY from '@salesforce/schema/ICY_Document__c.Category__c';
//Get Object Schema
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import DOCUMENT_OBJECT from '@salesforce/schema/ICY_Document__c';
import YTS_Interview_Generic_Validation_Msg from '@salesforce/label/c.YTS_Interview_Generic_Validation_Msg';
//Toast
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
//Apex Controller Actions
import upsertDocument from '@salesforce/apex/ICY_Notes_Documents_Controller.upsertDocument';
import getDocument from '@salesforce/apex/ICY_Notes_Documents_Controller.getDocument';

//Custom Labels
import ICY_UnableCreateDocument from '@salesforce/label/c.ICY_UnableCreateDocument';
import ICY_DocumentUpdatedSuccessfully from '@salesforce/label/c.ICY_DocumentUpdatedSuccessfully';
import ICY_DocumentCreatedSuccessfully from '@salesforce/label/c.ICY_DocumentCreatedSuccessfully';




const RESTRICTED_DESC = 'Restricted Case Documents will only be shared with the Navigator and the user who added the document. Any documents containing sensitive information should be uploaded as Restricted.';
const COLLAB_DESC = 'Collaborative Case Documents will be shared with all support team members for this individual\'s case. Collaborative documents should be relevant to assist others in picture and planning activities.';

export default class IcyCreateEditDocument extends LightningElement {

    @api parentRecordId;
    @api recordId;
    @api objectApiName;
    disableSaveButton = false;
    disableUploadButton = false;
    documentType
    typeDesc
    showOtherSubject = false;
    nextLabel = 'Save Document';
    fileName;
    isFileUploaded = false;
    missingFile = false;
    contentDocumentId;

    @track document={
        Name: '',
        Category__c: '',
        Other_Document_Type__c:'',
        Description__c: ''
    }

    @wire(getObjectInfo, {objectApiName: DOCUMENT_OBJECT}) objectInfo;
    //Type Of Referral
    @wire(getPicklistValues,{
        recordTypeId: '$objectInfo.data.defaultRecordTypeId',
        fieldApiName: CATEGORY
    }) categoryValues;

    get documentTypeOptions(){
        return [
            {label: 'Restricted', value: 'Restricted'},
            {label: 'Collaborative', value: 'Collaborative'}
        ]
    }

    get windowTitle(){
        return this.recordId?'Edit Document':'Add New Document';
    }


    /**
     * Connected Call Back
     */
    connectedCallback(){
        console.log('$$ Parent Record Id: ', this.parentRecordId);
        console.log('$$ Record Id: ', this.recordId);
        if(this.recordId){
            this.isFileUploaded = true
            getDocument({recordId: this.recordId}).then(result => {
                console.log('$$ Result: ', result);
                if(result){
                    this.document = result;
                    this.documentType = result.RecordType.DeveloperName;
                    if(result.Sub_Category__c){
                        this.note.Category__c = 'Other';
                        this.showOtherSubject = true;
                        this.note.Other_Document_Type__c = result.Category__c + ' - ' + result.Sub_Category__c;
                    }
                    if(result.Category__c == 'Other'){
                        this.showOtherSubject = true;
                    }
                    // if(this.documentType == 'Restricted')
                    //     this.typeDesc = RESTRICTED_DESC;
                    // else if(this.documentType == 'Collaborative')
                    //     this.typeDesc = COLLAB_DESC;

                }
            }).catch(error=>{
                console.error(error)
            });
        }
    }

    /**
     * Handle Chnage
     */
    handleChange(event){
        if(event.target.name){
            switch(event.target.name){
                case 'Type__c':
                    this.documentType = event.target.value;
                    // if(event.target.value == 'Restricted')
                    //     this.typeDesc = RESTRICTED_DESC;
                    // else if(event.target.value == 'Collaborative')
                    //     this.typeDesc = COLLAB_DESC;
                    break;
                case 'Category__c':
                    this.document.Category__c = event.target.value;
                    if(event.target.value == 'Other'){
                        this.showOtherSubject = true;
                    }else{
                        this.showOtherSubject = false;
                        this.document.Other_Document_Type__c = '';
                    }
                    break;
                case 'Other_Document_Type__c':
                    this.document.Other_Document_Type__c = event.target.value;
                    break;
                case 'Description__c':
                    this.document.Description__c = event.target.value;
                    break;
                case 'Name':
                    this.document.Name = event.target.value;
                    break;
            }
        }
    }

    //Close Modal
    closeModal() {
        const closeEvent = new CustomEvent(
            'close'
        );
        this.dispatchEvent(closeEvent);
    }

    //Save Note
    handleSave(){
        this.disableSaveButton = true;
        if(!this.documentType) this.documentType = 'Collaborative';
        if(this.recordId){
            upsertDocument({document: this.document, recordId: this.parentRecordId,
                documentId: this.recordId, recordTypeDeveloperName: this.documentType
            }).then(result =>{
                this.isFileUploaded = false;
                if(result) console.log('$$ Document upserted, ', result);
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: ICY_DocumentUpdatedSuccessfully,
                        variant: 'success',
                    }),
                );
                this.closeModal();
            }).catch(error=>{
                this.disableSaveButton = false;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: ICY_UnableCreateDocument,
                        variant: 'success',
                    }),
                );
                console.error('$$ Error saving Document: ', error);
            });
        }else{
            upsertDocument({document: this.document, recordId: this.parentRecordId,
                            documentId: this.recordId, recordTypeDeveloperName: this.documentType,
                            contentDocumentId: this.contentDocumentId
                        }).then(result =>{
                this.isFileUploaded = false;
                if(result) console.log('$$ Document upserted, ', result);
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: ICY_DocumentCreatedSuccessfully,
                        variant: 'success',
                    }),
                );
                this.closeModal();
            }).catch(error=>{
                this.disableSaveButton = false;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: ICY_UnableCreateDocument,
                        variant: 'success',
                    }),
                );
                console.error('$$ Error saving Case Document: ', error);
            });
        }

    }

    //Validate and Save
    validateAndSave(){
        let isValid = true;
        let inputFields = this.template.querySelectorAll('.validate');
        inputFields.forEach(inputField => {
            if (!inputField.checkValidity()) {
                inputField.reportValidity();
                isValid = false;
            }
        });
        if(!this.isFileUploaded){
            this.missingFile = true;
            isValid = false;
        }

        if(isValid){
            this.handleSave();
        }
        else{
            const evt = new ShowToastEvent({
                title: YTS_Interview_Generic_Validation_Msg,
                variant: 'error'
            });
            this.dispatchEvent(evt);
        }
    }

    //close Modal on Click on Esc
    handleKeyDown(event) {
        if(event.code == 'Escape') {
            this.closeModal();
            event.preventDefault();
            event.stopImmediatePropagation();
        }
    }

    handleUploadFinished(event){
        console.log('$$ Uploaded files: '+event.detail.files[0]);
        this.missingFile = false;
        this.isFileUploaded = true;
        let uploadedFile = event.detail.files[0];
        this.contentDocumentId = uploadedFile.documentId;
        this.fileName = uploadedFile.name;
        this.disableUploadButton = true;
    }

}