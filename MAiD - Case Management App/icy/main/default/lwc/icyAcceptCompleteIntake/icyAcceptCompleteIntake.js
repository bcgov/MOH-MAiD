import { LightningElement, api } from 'lwc';
 
export default class IcyAcceptCompleteIntake extends LightningElement {
    @api recordId;
    showScreen = true;
    rationaleRequired = false;
    uploadRequired = false;
    acceptIntakecaseDisable = false;

    get acceptedFormats() {
        return ['.pdf', '.png'];
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

    handleUploadFinished(event) {
        // Get the list of uploaded files
        const uploadedFiles = event.detail.files;
        alert('No. of files uploaded : ' + uploadedFiles.length);
    }


    handleChange(event) {
        let question1value = event.detail.value;
        if (question1value == 'Yes') {
            var divblock = this.template.querySelector('[data-id="question2"]');
            if (divblock) {
                this.template.querySelector('[data-id="question2"]').className = 'slds-show';
                this.template.querySelector('[data-id="question5"]').className = 'slds-hide';
                this.acceptIntakecaseDisable = false;
            }
        } else if (question1value == 'No') {
            var divblock = this.template.querySelector('[data-id="question5"]');
            if (divblock) {
                this.template.querySelector('[data-id="question5"]').className = 'slds-show';
                this.template.querySelector('[data-id="question2"]').className = 'slds-hide';
                this.template.querySelector('[data-id="question3"]').className = 'slds-hide';
                this.template.querySelector('[data-id="question4"]').className = 'slds-hide';
                this.acceptIntakecaseDisable = true;
            }
        }

    }
    handleChange2(event) {
        let question2value = event.detail.value;
        if (question2value == 'Verbal') {
            var divblock = this.template.querySelector('[data-id="question3"]');
            if (divblock) {
                this.rationaleRequired = true;
                this.uploadRequired = false;
                this.template.querySelector('[data-id="question3"]').className = 'slds-show';
                this.template.querySelector('[data-id="question4"]').className = 'slds-hide';
            }
        } else if (question2value == 'Signed Document') {
            var divblock = this.template.querySelector('[data-id="question4"]');
            if (divblock) {
                this.rationaleRequired = false;
                this.uploadRequired = true;
                this.template.querySelector('[data-id="question4"]').className = 'slds-show';
                this.template.querySelector('[data-id="question3"]').className = 'slds-hide';
            }
        }

    }
}