import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
//Apex Controller
import getAllCaseTeamMembers from '@salesforce/apex/ICY_CaseMember_Controller.getAllCaseTeamMembers';
import revokeCaseTeamMemberAccess from '@salesforce/apex/ICY_CaseMember_Controller.revokeCaseTeamMemberAccess';
import showSelfAccessButton from '@salesforce/apex/ICY_CaseMember_Controller.showSelfAccessButton';

export default class IcyCaseTeamMembers extends LightningElement {

    createEdit = false;
    deleteConfirm = false;
    members;
    @api parentRecordId;
    @api objectApiName;
    recordIdToBeRevoked;
    isSelfAccess = false;
    showSpinner = false;
    isSelfAccessBtn = false;


    addCaseMember(){
        this.createEdit = true;
    }

    closeModal(){
        this.createEdit = false;
        this.deleteConfirm  = false;
        this.recordIdToBeRevoked = null;
        this.isSelfAccess = false;
        this.init();
    }


    revokeAccess(event){
        console.log('$$ Revoked Record: ', event.target.dataset.id);
        this.recordIdToBeRevoked = event.target.dataset.id;
        this.deleteConfirm = true;
    }

    deleteConfirmation(){
        revokeCaseTeamMemberAccess({recordId: this.recordIdToBeRevoked}).then(result=>{
            const evt = new ShowToastEvent({
                title: 'Case Member Removed Successfully!!!',
                variant: 'success'
            });
            this.dispatchEvent(evt);
            this.closeModal();
        }).catch(error=>{
            console.error('$$ Error Revoking permission: ', error);
            const evt = new ShowToastEvent({
                title: 'Oops!! Unable to revoke permission Member. Please try again or contact Admin',
                variant: 'error'
            });
            this.dispatchEvent(evt);
            this.closeModal();
        })
    }

    connectedCallback(){
        this.init();
    }

    init(){
        this.showSpinner = true;
        getAllCaseTeamMembers({recordId: this.parentRecordId}).then(result=>{
            if(result.length > 0){
                this.members = [];
                this.members = result;
            }
            this.showSpinner = false;
            
        }).catch(error=>{
            this.showSpinner = false;
            console.error('$$ Error Retrieving Case members: ', error);
        })

        showSelfAccessButton({recordId: this.parentRecordId}).then(result=>{
            console.log('$$ Self access Btn: '+result);
            this.isSelfAccessBtn = (result && this.objectApiName != 'Case');
        }).catch(error=>{
            this.showSpinner = false;
            console.error('$$ Error self access button: ', error);
        })
    }

    createSelfAccess(){
        this.isSelfAccess = true;
        this.createEdit = true;
    }
}