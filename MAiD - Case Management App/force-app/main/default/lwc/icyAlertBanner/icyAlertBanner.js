import { LightningElement, api, wire } from 'lwc';
import fetchBannerDetails from '@salesforce/apex/ICY_AlertBannerCtrl.fetchBannerDetails';


export default class IcyAlertBanner extends LightningElement {

    @api recordId;
    @api objectApiName;
    showBanner;
    bannerAlertMsg;

    @wire(fetchBannerDetails, { strRecId: '$recordId', strSobject: '$objectApiName' }) 
    wiredReferralDetails({ error, data }) {
        if (data) {
            console.log('@@',data)
            if(this.objectApiName == 'Intake__c'){
                this.showBanner = data.Referral__r.ICY_Show_Banner__c;
                this.bannerAlertMsg = data.Referral__r.ICY_Alert_Banner_Text__c;
            } else {
                this.showBanner = data.ICY_Show_Banner__c;
                this.bannerAlertMsg = data.ICY_Alert_Banner_Text__c;
            }
        } else if (error) {
            console.log(JSON.stringify(error));
        }
    }

}