import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue, updateRecord, createRecord } from 'lightning/uiRecordApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import CONSENT_FIELD from '@salesforce/schema/Intake__c.ICY_Consent_Provided__c';
import STATUS_FIELD from '@salesforce/schema/Intake__c.Status__c';
import VERBAL_FIELD from '@salesforce/schema/Intake__c.ICY_Verbal_Consent__c';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import CASE_OBJECT from '@salesforce/schema/Case';
import createPersonAcct from '@salesforce/apex/ICY_CompleteIntakeCtrl.createPersonAcc';
import { NavigationMixin } from 'lightning/navigation';
import { deleteRecord } from 'lightning/uiRecordApi';

//Custom Labels
import ICY_IntakeCompletedSuccessfully from '@salesforce/label/c.ICY_IntakeCompletedSuccessfully';

const fields = [CONSENT_FIELD, STATUS_FIELD, VERBAL_FIELD];
const InTakeRECFIELDS = ['Intake__c.CreatedDate', 'Intake__c.Referral__r.CreatedDate','Intake__c.Referral__r.ICY_Geographic_Area__c','Intake__c.Referral__r.Id'];
const RESTRICTED_DESC = 'Restricted Case Documents will only be shared with the Navigator and the user who added the document. Any documents containing sensitive information should be uploaded as Restricted.';
const COLLAB_DESC = 'Collaborative Case Documents will be shared with all support team members for this individual\'s case. Collaborative documents should be relevant to assist others in picture and planning activities.';

export default class IcyCompleteIntakeLWC extends NavigationMixin(LightningElement)  {
    @api recordId;
    showScreen1 = true;
    showScreen2 = false;
    disableNext = true;
    makeRationaleReq = false;
    makeSignedDocReq = false;
    disableSubmit = true;
    rationale;
    caseObjectInfo;
    showSpinner;
    contentDocumentId;
    signedContentDocumentId;
    inTakeRec;
    typeDesc;
    isFileUploaded;
    disableNextDocTypeSelected= true;
    disableNextDocTypeSelected2= true;
    isSignedFileUploaded;
    fileName;
    signedFileName;
    documentType;
    documentTypeSigned;

    get acceptedFormats() {
        return ['.pdf', '.png', '.txt', '.xlsx', '.doc', '.docx'];
    }

    get options() {
        return [
            { label: 'Yes', value: 'Yes' },
            { label: 'No', value: 'No' },
        ];
    }

    get options2() {
        return [
            { label: 'Verbal', value: 'Verbal' },
            { label: 'Signed Document', value: 'Signed Document' },
        ];
    }

    get documentTypeOptions(){
        return [
            {label: 'Restricted', value: 'Restricted'},
            {label: 'Collaborative', value: 'Collaborative'}
        ]
    }

    @wire(getObjectInfo, { objectApiName: CASE_OBJECT, })
    caseObjectInfo;

    @wire( getRecord, { recordId: '$recordId', fields: InTakeRECFIELDS  } )
    wiredRecord({ error, data }) {
        if ( data ) {
            this.inTakeRec = data;
            console.log('Error'+JSON.stringify(this.inTakeRec));
        }else if(error) {
            console.log('Error'+JSON.stringify(error));
        }
    }

    getRecordTypeId(recordTypeName) {
        let recordtypeinfo = this.caseObjectInfo.data.recordTypeInfos;
        let recordTypeId;
        for (var eachRecordtype in recordtypeinfo) {
            if (recordtypeinfo[eachRecordtype].name === recordTypeName) {
                recordTypeId = recordtypeinfo[eachRecordtype].recordTypeId;
                break;
            }
        }
        console.log('returning -   ' + recordTypeId);
        return recordTypeId;
    }

    handleUploadFinished(event) {
        // Get the list of uploaded files
        const uploadedFiles = event.detail.files;
        this.contentDocumentId = uploadedFiles[0].documentId;
        this.disableNext = false;
        this.isFileUploaded = true;
        this.fileName = uploadedFiles[0].name;
    }

    handleUploadFinished1(event) {
        // Get the list of uploaded files
        const uploadedFiles = event.detail.files;
        this.signedContentDocumentId = uploadedFiles[0].documentId;
        this.disableSubmit = false;
        this.isSignedFileUploaded = true;
        this.signedFileName = uploadedFiles[0].name;
    }

    handleNext() {
            this.showScreen1 = false;
            this.showScreen2 = true;
    }
    /**
     * Handle Chnage
     */
    handleChange(event){
        if(event.target.name){
            switch(event.target.name){
                case 'Type__c':
                    this.documentType = event.target.value;
                    this.disableNextDocTypeSelected= false;                 
                    if(event.target.value == 'Restricted')
                        this.typeDesc = RESTRICTED_DESC;
                    else if(event.target.value == 'Collaborative')
                          this.typeDesc = COLLAB_DESC;
                    break;
                case 'SignedDoucType__c':
                    this.documentTypeSigned = event.target.value;
                    this.disableNextDocTypeSelected2= false;
                    if(event.target.value == 'Restricted')
                        this.typeDescSigned = RESTRICTED_DESC;
                    else if(event.target.value == 'Collaborative')
                        this.typeDescSigned = COLLAB_DESC;
                    break;

            }
        }

    }
    handleChange2(event) {
        let question2value = event.detail.value;
        if (question2value == 'Verbal') {
            this.disableSubmit= (this.rationale == '') || (this.rationale == undefined);
            this.disableNextDocTypeSelected2 = (this.rationale == '') || (this.rationale == undefined);
            var divblock = this.template.querySelector('[data-id="question3"]');
            if (divblock) {
                this.makeRationaleReq = true;
                this.makeSignedDocReq = false;
                this.template.querySelector('[data-id="question3"]').className = 'slds-show';
                this.template.querySelector('[data-id="question4"]').className = 'slds-hide';

            }
        } else if (question2value == 'Signed Document') {
            this.disableSubmit= (this.documentTypeSigned != 'Restricted' && this.documentTypeSigned != 'Collaborative' && !this.isSignedFileUploaded );
            this.disableNextDocTypeSelected2 = (this.documentTypeSigned != 'Restricted' && this.documentTypeSigned != 'Collaborative' && !this.isSignedFileUploaded );
            
            var divblock = this.template.querySelector('[data-id="question4"]');
            if (divblock) {
                this.makeSignedDocReq = true;
                this.makeRationaleReq = false;
                this.template.querySelector('[data-id="question4"]').className = 'slds-show';
                this.template.querySelector('[data-id="question3"]').className = 'slds-hide';
            }
        }


    }
    captureRationale(event) {
        this.rationale = event.detail.value;
        this.disableSubmit =  (this.rationale == '') || (this.rationale == undefined);
        this.disableNextDocTypeSelected2 = (this.rationale == '') || (this.rationale == undefined);
    }

    handleSubmit() {
            this.showSpinner = true
            var caseId;

            let casefields = { 'Status': 'Open', 'ICY_Consent__c': true,
                                'RecordTypeId': this.getRecordTypeId('ICY Standard Case'),
                                'ICY_Date_Intake_Happened__c': this.inTakeRec.fields.CreatedDate.value,
                                'ICY_Referral_Date__c': this.inTakeRec.fields.Referral__r.value.fields.CreatedDate.value,
                                'ICY_Geographic_Area__c':this.inTakeRec.fields.Referral__r.value.fields.ICY_Geographic_Area__c.value,
                                'Referral__c':this.inTakeRec.fields.Referral__r.value.fields.Id.value
                                };

            // Record details to pass to create method with api name of Object.
            let objCase = { 'apiName': 'Case', fields: casefields };
            // LDS method to create record.
            createRecord(objCase).then(response => {

                createPersonAcct({ strRecordId: this.recordId, strCaseID: response.id, strContentDoc: this.contentDocumentId,
                                    strDocumentType:this.documentType, strDocumentName: this.fileName, strSignedDoc: this.signedContentDocumentId,
                                    strSignedDocumentName: this.signedFileName, strDocumentTypeSigned: this.documentTypeSigned})
                    .then(result => {

                        let inTakefields = {
                            'Id': this.recordId,
                            'ICY_Consent_Provided__c': true,
                            'Status__c': 'Complete',
                            'ICY_Rationale__c': this.rationale, //Josh
                            'Case__c': response.id

                        }
                        var objIntake = { fields: inTakefields };

                        updateRecord(objIntake)
                            .then(() => {

                                this.dispatchEvent(
                                    new ShowToastEvent({
                                        title: '',
                                        message: ICY_IntakeCompletedSuccessfully ,
                                        variant: 'success'
                                    })
                                )
                                this.showSpinner = false;
                                this.closeQuickAction();
                                this.navigateNext(response.id);
                            })
                            .catch(error => {

                                this.showSpinner = false;
                                this.dispatchEvent(
                                    new ShowToastEvent({
                                        title: 'Error!',
                                        message: JSON.stringify(error.message),
                                        variant: 'error'
                                    })
                                )
                            })
                    })
                    .catch(error => {
                        deleteRecord(response.id)
                        .then(() => {
                            console.log('Record deleted successfully');
                        })
                        .catch(error => {
                            console.error('Error deleting record:', error);
                        });

                        this.showSpinner = false;
                        console.error('Error: ' + JSON.stringify(error.message));
                        alert('Error in createPersonAcct Notify your administrator');
                    })

            }).catch(error => {
                this.showSpinner = false;
                console.error('Error: ' + JSON.stringify(error.message));
            });
            
    }

    closeQuickAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    navigateNext(reponseDetails) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: reponseDetails,
                objectApiName: 'Case',
                actionName: 'view'
            },
        });
    }
   
    get isButtonNextDisabled(){
        return (this.disableNextDocTypeSelected || this.disableNext);
     }

     get isButtonSubmitDisabled(){
        return (this.disableNextDocTypeSelected2 || this.disableSubmit);
     }

}