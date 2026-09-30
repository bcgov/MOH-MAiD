import { LightningElement, wire } from 'lwc';
import getHierarchyCustomSetting from '@salesforce/apex/ICY_CustomSettingsController.getHierarchyCustomSetting';

export default class IcyAlertBannerOutage extends LightningElement {
    showBanner;
    bannerOutageMsg;
    hierarchyCustomSetting;

    @wire(getHierarchyCustomSetting)
    wiredHierarchyCustomSetting({ error, data }) {
        if (data) {
            this.hierarchyCustomSetting = data;
            this.showBanner = this.hierarchyCustomSetting.Outage__c ;
            this.bannerOutageMsg = this.hierarchyCustomSetting.Outage_Message__c;
        } else   
            this.showBanner = false;
    }
}
