import { LightningElement, api } from 'lwc';

export default class YtsAccountInfo extends LightningElement {
    @api accountId;
    @api isAccountReadOnly = false;

    get modeValue(){
        if(!this.isAccountReadOnly) return "view";
        return "readonly";
    }
}