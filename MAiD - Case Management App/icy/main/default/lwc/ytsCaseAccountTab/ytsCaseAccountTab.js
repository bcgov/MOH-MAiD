import { LightningElement, api, wire, track } from 'lwc';
import getCaseAccountId from '@salesforce/apex/YTS_Referral_Controller.getCaseAccountId';
import getCaseStatus from '@salesforce/apex/YTS_Referral_Controller.getCaseStatus';

export default class YtsCaseAccountTab extends LightningElement {

    @api recordId;
    @track accountId;
    @track isAccountReadOnly = false;

    connectedCallback(){
        getCaseAccountId({ caseId: this.recordId }).then(result=>{
            if(result) this.accountId = result;
            return getCaseStatus({caseId: this.recordId});
        }).then(result => {
            if(result){
                if(result == 'Closed')
                    this.isAccountReadOnly = true;
            }
        }).catch(error=>{
            console.error('$$ Error Retrieving Case Details');
        })
    }

}