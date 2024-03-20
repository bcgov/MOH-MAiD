import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { deleteRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

//Apex Class Controllers
import getRelatedDocuments from '@salesforce/apex/ICY_Notes_Documents_Controller.getRelatedDocuments';
import getContentDistributionForFile from '@salesforce/apex/ICY_Notes_Documents_Controller.getContentDistributionForFile';

//Custom Labels
import ICY_UnableToDownloadDocument from '@salesforce/label/c.ICY_UnableToDownloadDocument';
import ICY_UnableToDeleteDocument from '@salesforce/label/c.ICY_UnableToDeleteDocument';
import ICY_DocumentDeleted from '@salesforce/label/c.ICY_DocumentDeleted';


export default class icyDocumentsComponent extends NavigationMixin(LightningElement) {

    @api objectApiName;
    @api parentRecordId;
    documentId;
    deleteConfirm = false;
    @track showAddBtn = true;
    showSpinner = false;
    documents;
    createEdit = false;
    title = 'Document Details';

    connectedCallback() {
        this.init();
    }

    /**
     * Component Initialize
     */
    init() {
        this.showSpinner = true;
        getRelatedDocuments({ recordId: this.parentRecordId }).then(result => {
            this.showSpinner = false;
            console.log('$$ Result', result);
            if (result) {
                this.showAddBtn = result.isParentCompleted;
                if(result.hasOwnProperty('lstDocument')){
                    this.documents = [];
                    this.documents = result.lstDocument;
                }
            }
        }).catch(error => {
            this.showSpinner = false;
            console.error('$$ Error Retrieving documents: ', error);
        });
    }


    /**
     * File Attachment Preview
    */
    preview(event) {
        console.log('$$ Selected Doc Id: ', event.target.dataset.id)
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: {
                pageName: 'filePreview'
            },
            state: {
                selectedRecordId: event.target.dataset.id
            }
        });
    }

    /**
     * Download COntent DOcuments
     * @param {*} event
     */
    download(event) {
        getContentDistributionForFile({contentDocumentId: event.target.dataset.id}).then(result=>{
            window.open(result.ContentDownloadUrl);
        }).catch(error=>{
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: ICY_UnableToDownloadDocument,
                    variant: 'error'
                })
            );
            console.error('$$ Error Downloading : '+JSON.stringify(error));
        });
    }

    /**
     * Download File Attachments
     * @param {*} event
     */
     downloadAttachment(event){
         event.preventDefault();
        let docId = event.target.dataset.id;
        window.open('/servlet/servlet.FileDownload?file='+docId);
     }

/**
     * edit case_document__c details
     * @param {*} event
     */
    editDocument(event) {
        this.documentId = event.target.dataset.id;
        this.createEdit = true;
    }

    /**
     * delete case_document__c
     * @param {*} event
     */
    handleDelete(event) {
        console.log('$$ selected Id for Delete ', event.target.dataset.id);
        this.documentId = event.target.dataset.id;
        this.deleteConfirm = true;
    }



    addDocument() {
        this.createEdit = true;
    }

    closeModal() {
        this.createEdit = false;
        this.documentId = null;
        this.init();
    }

    /**
     * delete confirmation
     */
    deleteConfirmation() {
        deleteRecord(this.documentId).then(() => {
            this.documentId = null;
            this.closeConfirmation();
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: ICY_DocumentDeleted,
                    variant: 'success'
                })
            );
        }).catch(error => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: ICY_UnableToDeleteDocument,
                    variant: 'error'
                })
            );
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