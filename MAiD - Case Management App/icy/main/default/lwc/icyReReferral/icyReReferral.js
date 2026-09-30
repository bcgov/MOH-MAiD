import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class icyReReferral extends LightningElement {
    @api recordId;
    @api objectApiName;
    referralDateRequired=false;

    @track showDate = false;
    dateValue = null;
    isSubmitting = false;
    checkboxValue = false;
    _initialized = false;

    renderedCallback() {
        // Keep for compatibility but rely on form's onload to populate values
        if (this._initialized) return;
        this._initialized = true;
    }

    handleLoad(event) {
        // Fired when lightning-record-edit-form has loaded record data
        try {
            const record = event.detail.record;
            // Always initialize checkbox as unchecked on load per requirement
            this.checkboxValue = false;
            this.showDate = false;
            this.referralDateRequired = false;
            this.dateValue = null;
        } catch (e) {
            // ignore
        }

    }



    handleCheckboxChange(event) {
        const isChecked = event.target.checked === true;
        this.checkboxValue = isChecked;
        this.showDate = isChecked;
        this.referralDateRequired = isChecked;

        if (isChecked) {
            if (!this.dateValue) {
                this.dateValue = this.getTodayDateString();
            }
        } else {
            this.dateValue = null;
        }
    }

    handleDateChange(event) {
        this.dateValue = event.target.value;
    }

    handleCancel() {
    this.showDate = false;
    this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleSuccess() {
        // reset submitting state then close
        this.isSubmitting = false;
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Record updated',
                variant: 'success'
            })
        );
     this.dispatchEvent(new CloseActionScreenEvent());
     // Reload the page after a short delay to allow the screen to close
     setTimeout(() => {
         location.reload();
     }, 500);
    }
  
    
    handleSubmit(event) {
    // Intercept submit to control payload
    event.preventDefault();

    // prevent duplicate submits
    if (this.isSubmitting) return;
    this.isSubmitting = true;

    // fields is the payload to send
    const fields = event.detail.fields;

    // Use the component-controlled checkbox value rather than relying on form payload
    const isChecked = this.checkboxValue === true;
    fields.Re_Referral__c = isChecked;
    if (!isChecked) {
        fields.Re_Referral_Date__c = null;
    } else {
        fields.Re_Referral_Date__c = this.dateValue || this.getTodayDateString();
    }

    // Submit with controlled fields
    this.template.querySelector('lightning-record-edit-form').submit(fields);
}

    handleError(event) {
        // Re-enable submit button on error
        this.isSubmitting = false;
        const message = event?.detail?.message || 'An error occurred while saving.';
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message,
                variant: 'error'
            })
        );
    }

    getTodayDateString() {
    // Returns today's date in ISO format (YYYY-MM-DD)
    const today = new Date();
    const year = today.getFullYear();
    const month = String(today.getMonth() + 1).padStart(2, '0');
    const day = String(today.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
    }
   
}
