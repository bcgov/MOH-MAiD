import { LightningElement, api} from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

import createICYIntakeRecord from '@salesforce/apex/ICY_Referral_Controller.createICYIntakeRecord'
 
export default class IcyCreateInTakeRecord extends NavigationMixin(LightningElement) {
    @api recordId;
    showSpinner = false;

    connectedCallback(){
        console.log('$$ Record Id: ', this.recordId);
    }


    createIntake() {
        this.showSpinner = true;
        console.log('rendered@ recordId', this.recordId);
        createICYIntakeRecord({referralId: this.recordId}).then(result=>{
            this.showSpinner = false;
            console.log('$$ Intake Created Successfully: ');
            if(result){
                this.navigateNext(result);
                this.showToast();
            }
        }).catch(error=>{
            this.showSpinner = false;
            console.error('$$ Error Creating Intake: ', error);
            const event = new ShowToastEvent({
                title: 'error',
                message: 'Unable to Create Intake!!! '+error,
                variant: 'error',
                mode: 'dismissable'
            });
            this.dispatchEvent(event);
        })
    }

    /**
     * Close Quick Action
     */
     closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showToast() {
        const event = new ShowToastEvent({
            title: 'Intake Created Successfully',
            message: '',
            variant: 'success',
            mode: 'dismissable'
        });
        this.dispatchEvent(event);
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
}