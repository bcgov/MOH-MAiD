import { LightningElement,api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import disableBanner from '@salesforce/apex/ICY_AlertBannerCtrl.disableBannerAlert';
import { NavigationMixin } from 'lightning/navigation';

export default class IcyDisableBannerAlert extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName;
    recordPageUrl;

    @api invoke() {
        disableBanner({ strRecId: this.recordId, strSobject: this.objectApiName })
        .then((result) => {
            if(result == 'Banner Alert Updated') {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success!',
                        message: 'Banner Alert Disabled Successfully',
                        variant: 'success'
                    })
                )
                this.navigateToTheRecord(this.recordId);
            }
        })
        .catch((error) => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error!',
                    message: JSON.stringify(error.message),
                    variant: 'error'
                })
            )
        });
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