import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class icyReReferral extends LightningElement {
    @api recordId;
    @api objectApiName;

    @track showDate = false;
    defaultDate;

    handleCheckboxChange(event) {
        const isChecked = event.target.value;
        this.showDate = isChecked;

        if (isChecked) {
            // Default datetime = now
            this.defaultDate = new Date().toISOString();
        } else {
            // Auto-clear date when unchecked
            this.defaultDate = null;
        }
    }

    handleCancel() {
        this.showDate = false;
        this.defaultDate = null;
    }

    handleSuccess() {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Record updated',
                variant: 'success'
            })
        );
    }
}
