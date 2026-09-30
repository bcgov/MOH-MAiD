import { LightningElement,api,wire } from 'lwc';
import checkClosedDate from '@salesforce/apex/ICY_ReopenCaseCtrl.checkClosedDate';
import notifyManagerONcaseReopening from '@salesforce/apex/ICY_ReopenCaseCtrl.sendEmailNotificationToLocationManager';
import {createRecord,updateRecord } from 'lightning/uiRecordApi';
import INTAKE_OBJECT from '@salesforce/schema/Intake__c';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { NavigationMixin } from 'lightning/navigation'; 
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

//Custom Labels
import ICY_SomethingWentWrong from '@salesforce/label/c.ICY_SomethingWentWrong';

export default class IcyReopenCase extends NavigationMixin(LightningElement)  {

    @api recordId
    canCaseBeReopened;
    showMsg;
    referralObj;
    intakeId =null;

    @wire( checkClosedDate, ({ caseId : '$recordId' }))
    wiredRecord({ data, error }) {
        if ( data ) {
            this.canCaseBeReopened = data;
            if(this.canCaseBeReopened == 'Yes') {
                this.updateCaseStatus();;
            } 
        }else if(error) {
            console.log(JSON.stringify(error))
            this.canCaseBeReopened = 'No';
        }
    }

    @wire(getObjectInfo, { objectApiName: INTAKE_OBJECT, })
    inTakeObjectInfo;

    getRecordTypeId(recordTypeName) {
        let recordtypeinfo = this.inTakeObjectInfo.data.recordTypeInfos;
        let recordTypeId;
        for (var eachRecordtype in recordtypeinfo) {
            if (recordtypeinfo[eachRecordtype].name === recordTypeName) {
                recordTypeId = recordtypeinfo[eachRecordtype].recordTypeId;
                break;
            }
        }
        return recordTypeId;
    }

    updateCaseStatus(){
        let casefields = { 'Status': 'Open',
                            'Id': this.recordId
                            };
        // Record details to pass to create method with api name of Object.
        let objCase = { fields: casefields };
        updateRecord(objCase)
                    .then(() => {
                        this.sendEmailNotification();
                    })
                    .catch(error => {
                        console.log('@@error',error);
                        this.dispatchEvent(
                            new ShowToastEvent({
                                title: 'Error!',
                                message: JSON.stringify(error.message),
                                variant: 'error'
                            })
                        )
                    })
    }

    navigateNext(reponseDetails) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: reponseDetails,
                objectApiName: 'Intake__c',
                actionName: 'view'
            },
        });
    }
 
    sendEmailNotification(){
        notifyManagerONcaseReopening({caseId: this.recordId})        
        .then(result => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success!',
                    message: 'Case reopened',
                    variant: 'success'
                })
            )
            if(this.intakeId){
                this.navigateNext(this.intakeId); 
            }
            this.closeQuickAction();
        }).catch(error => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error!',
                    message: 'Something went wrong, please try again '+JSON.stringify(error.message),
                    variant: 'error'
                })
            )
            console.log('error',error);
        });
    }

    closeQuickAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}