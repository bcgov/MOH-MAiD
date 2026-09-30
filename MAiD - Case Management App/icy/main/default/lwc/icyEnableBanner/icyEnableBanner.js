import { LightningElement,api, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import updateBannerDetails from '@salesforce/apex/ICY_AlertBannerCtrl.UpdateBannerDetails';
import fetchBannerMessage from '@salesforce/apex/ICY_AlertBannerCtrl.fetchBannerDetails';
import { NavigationMixin } from 'lightning/navigation';

export default class IcyEnableBanner extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName;
    alertMsg=null;
    showSpinner;
    bannerMessage;
    recordPageUrl;
    
    @wire(fetchBannerMessage, { strRecId: '$recordId', strSobject: '$objectApiName' }) 
    wiredBannerDetails({ error, data }) {
        if (data) {
            if(this.objectApiName == 'Intake__c'){
                this.alertMsg = data.Referral__r.ICY_Alert_Banner_Text__c;
            }else if(this.objectApiName == 'Case'){
                this.alertMsg = data.ICY_Alert_Banner_Text__c;
            }else if(this.objectApiName == 'Referral__c'){
                this.alertMsg = data.ICY_Alert_Banner_Text__c;
            }
        } else if (error) {
            console.log(JSON.stringify(error));
        }
    }

    handleChange(event){
        this.alertMsg = event.detail.value;
    }
    
    handleSubmit() {
        this.showSpinner = true;
        updateBannerDetails({ strRecId: this.recordId, strSobject: this.objectApiName, strBannerMSg: this.alertMsg })
            .then((result) => {
                if(result == 'Banner Alert Updated') {
                   
                    console.log('@@1');
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Success!',
                            message: 'Banner Alert Updated Successfully',
                            variant: 'success'
                        })
                    )
                    this.showSpinner = false;
                    this.closeQuickAction();
                    this.navigateToTheRecord(this.recordId);
                }
            })
            .catch((error) => {
                this.showSpinner = false;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error!',
                        message: JSON.stringify(error.message),
                        variant: 'error'
                    })
                )
            });
    }

    closeQuickAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    navigateToTheRecord(recordId){
        this[NavigationMixin.GenerateUrl]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                actionName: 'view',
            },
        }).then((url) => {
            this.recordPageUrl = url;
            window.location.replace(this.recordPageUrl);
        });
    }

}