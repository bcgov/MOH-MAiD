import { LightningElement, api, wire  } from 'lwc';
//Custom Labels
import ICY_PrivacyAgreement from '@salesforce/label/c.ICY_PrivacyAgreement';


export default class IcyAlertBannerPrivacyAgreement extends LightningElement {
    
    get showPrivacyLabel() {
        // Check if the checkbox field value is true
        return ICY_PrivacyAgreement;
    }
}