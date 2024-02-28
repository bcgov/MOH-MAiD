import { LightningElement,api,wire } from 'lwc';
import checkClosedDate from '@salesforce/apex/ICY_ReopenCaseCtrl.checkClosedDate';
import getReferralRelatedToCase from '@salesforce/apex/ICY_ReopenCaseCtrl.getReferralDetails';
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
    past91Days;
    showMsg;
    referralObj;
    intakeId =null;

    @wire( checkClosedDate, ({ caseId : '$recordId' }))
    wiredRecord({ data, error }) {
        if ( data ) {
            this.past91Days = data;
            if(this.past91Days == 'Yes') {
                this.getRefDetails();
            }else{
                this.updateCaseStatus();
            }
        }else if(error) {
            console.log(JSON.stringify(error))
            this.past91Days = 'No';
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

    createIntake(){
        let inTakefields = { 'RecordTypeId': this.getRecordTypeId('ICY Intake'),
                            'Case__c': this.recordId,
                            'Referral__c':this.referralObj.Id
                            };
        let objInTake = { 'apiName': 'Intake__c', fields: inTakefields };
        createRecord(objInTake).then(response => {
            this.sendEmailNotification();
            this.intakeId = response.id;            
        }).catch(error => {
            alert('Error: ' + JSON.stringify(error.message));
        })
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

    getRefDetails(){
        getReferralRelatedToCase({caseId: this.recordId})        
            .then(result => {
                this.referralObj= result;
                if(this.referralObj){
                    this.createIntake();
                }
            }).catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error!',
                        message: ICY_SomethingWentWrong +JSON.stringify(error.message),
                        variant: 'error'
                    })
                )
                console.log('error',error);
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