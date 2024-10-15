import { LightningElement, api } from 'lwc';
import getRecordTypeName from '@salesforce/apex/ICY_Referral_Controller.getRecordTypeName';
import isUserPartOfCaseMembers from '@salesforce/apex/ICY_Referral_Controller.isUserPartOfCaseMembers';


export default class IcyReferralRecordInfo extends LightningElement {
    @api recordId;
   
    activeSections = ['A','B','C','D','E','F'];
    isGeneralReferral = false;
    isMedicalReferral = false;
    showAdditionalInfo = false;

       connectedCallback(){
        if(this.recordId){
            getRecordTypeName({recordId: this.recordId}).then(result=>{
                if(result){
                    if(result.includes('General')) {
                        this.isGeneralReferral = true;
                        this.isMedicalReferral = false;
                    }
                    else if(result.includes('Professional')) {
                        this.isMedicalReferral = true;
                        this.isGeneralReferral = false;
                    }
                }
            }).catch(error=>{
                console.error('$$ Error getting record Type: '+error);
            });
            //Check If User if part of case members
            isUserPartOfCaseMembers({recordId: this.recordId}).then(result=>{
                console.log('$$ isUserPartOfCaseMembers: ', result);
                this.showAdditionalInfo = result;
                if(result) this.activeSections = ['A','B','C','D','E','F'];
            }).catch(error=>{
                console.error('$$ isUserPartOfCaseMembers: ', error)
            })
        }
    }
}