import { LightningElement,api,wire } from 'lwc';
import { updateRecord } from 'lightning/uiRecordApi'; 
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation'; 
import { CurrentPageReference } from 'lightning/navigation';

const OPEN_STATUS = 'Referral';

export default class IcyReopenReferral extends NavigationMixin(LightningElement)   {
    @api recordId;

    @wire(CurrentPageReference)
    pageRef;

    get recordId() {
        return this.pageRef && this.pageRef.state ? this.pageRef.state.recordId : null;
    }  

    connectedCallback() {
        let referralfields = { 'Status__c': OPEN_STATUS,
            'Referral_Close_Reason__c': '',
            'ICY_Rationale_For_Closure__c':'',
            'ICY_Reopened_Date__c':new Date().toISOString().slice(0, 10),
            'ICY_Closed_Date__c':'',
            'Id': this.recordId
            };
        let objReferral = { fields: referralfields };
        updateRecord(objReferral)
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Referral reopened',
                        variant: 'success'
                    })
                );
                this.closeQuickAction();
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

closeQuickAction() {
this.dispatchEvent(new CloseActionScreenEvent());
}
}