import { LightningElement, api, wire, track} from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
//Apex Controller
import getPicklistvalues from '@salesforce/apex/ICY_Referral_Controller.getPicklistvalues';
import upsertCaseMember from '@salesforce/apex/ICY_CaseMember_Controller.upsertCaseMember';
//Custom Labels
import YTS_Interview_Generic_Validation_Msg from '@salesforce/label/c.YTS_Interview_Generic_Validation_Msg';
import ICY_CaseMemberAdded from '@salesforce/label/c.ICY_CaseMemberAdded';
import ICY_UnableToAddMember from '@salesforce/label/c.ICY_UnableToAddMember';


export default class IcyCreateEditCaseTeamMember extends LightningElement {

    @api parentId;
    @api recordId;
    @api objectApiName;
    @api isSelfAccess;
    
    categoryAssignmentOptions;
    statusOptions;
    isUser = false
    isContact = false
    showSpinner = false;
    endDateRequired = false;

    @track 
    caseMember = {
        ICY_Category_Assignment__c:'',
        ICY_End_Date__c: '',
        ICY_Status__c: 'Active',
        ICY_User__c: '',
        ICY_Case_Contact__c:''
    }

    


    //Category Assignment Values
    @wire(getPicklistvalues, {
        objectApiName: 'Case_Member__c',
        fieldApiName: 'ICY_Category_Assignment__c'
    }) getCategoryPicklistValues({error, data}){
        if(data){
            this.categoryAssignmentOptions = [];
            for(const [key, value] of Object.entries(data)){
                let temp ={
                    label:'',
                    value:''
                };
                temp.label = key;
                temp.value = value;
                this.categoryAssignmentOptions.push(temp);
            }
        }else if(error){
            console.error('$$ Error getting categoryAssignmentOptions options: '+error);
        }
    }

    //Status Values
    @wire(getPicklistvalues, {
        objectApiName: 'Case_Member__c',
        fieldApiName: 'ICY_Status__c'
    }) getStatusPicklistValues({error, data}){
        if(data){
            this.statusOptions = [];
            for(const [key, value] of Object.entries(data)){
                let temp ={
                    label:'',
                    value:''
                };
                temp.label = key;
                temp.value = value;
                this.statusOptions.push(temp);
            }
        }else if(error){
            console.error('$$ Error getting statusOptions options: '+error);
        }
    }


    handleChange(event){
        let t = event.target.name;
        if(t){
            switch (t) {
                case 'ICY_Category_Assignment__c':
                    this.caseMember.ICY_Category_Assignment__c = event.target.value;
                    if(this.isSelfAccess){
                        this.isUser = false;
                        this.isContact = false;
                    }else{
                        if(this.caseMember.ICY_Category_Assignment__c == 'Supplemental'){
                            this.isContact = true;
                            this.isUser = false;
                        }else {
                            this.isContact = false;
                            this.isUser = true;
                        }
                    }
                    break;
                case 'ICY_Case_Contact__c':
                    this.caseMember.ICY_Case_Contact__c = event.target.value;
                    break;
                case 'ICY_User__c':
                    this.caseMember.ICY_User__c = event.target.value;
                    break;
                case 'ICY_Status__c':
                    this.caseMember.ICY_Status__c = event.target.value;
                    break;
                case 'ICY_End_Date__c':
                    this.caseMember.ICY_End_Date__c = event.target.value;
                    break;
                default:
                    break;
            }
        }
    }

    //save
    validateAndSave(){
        let isValid = true;
        let inputFields = this.template.querySelectorAll('.validate');
        inputFields.forEach(inputField =>{
            if(!inputField.checkValidity()){
                inputField.reportValidity();
                isValid = false;
            }
        });
        if(isValid){
            this.handleSave();
        }else{
            const evt = new ShowToastEvent({
                title: YTS_Interview_Generic_Validation_Msg,
                variant: 'error'
            });
            this.dispatchEvent(evt);
        }
    }

    handleSave(){
        this.showSpinner =true;
        upsertCaseMember({cm: this.caseMember, parentRecordId: this.parentId, recordId: this.recordId, isSelfAccess: this.isSelfAccess}).then(result=>{
            this.showSpinner =false;
            if(result){
                if(result == 'SUCCESS'){
                    console.log('$$ Case Member Inserted: ');
                    const evt = new ShowToastEvent({
                        title: ICY_CaseMemberAdded,
                        variant: 'success'
                    });
                    this.dispatchEvent(evt);
                    this.closeModal();
                }else{
                    const evt = new ShowToastEvent({
                        title: result,
                        variant: 'error'
                    });
                    this.dispatchEvent(evt);
                }
            }
            
        }).catch(error=>{
            this.showSpinner =false;
            console.error('$$ Error Inserting Case Member: ', error);

            const evt = new ShowToastEvent({
                title: ICY_UnableToAddMember,
                variant: 'error'
            });
            this.dispatchEvent(evt);
        })
    }

    //close Modal on Click on Esc
    handleKeyDown(event) {
        if(event.code == 'Escape') {
            this.closeModal();
            event.preventDefault();
            event.stopImmediatePropagation();
        }
    }

    //Close Modal
    closeModal() {
        const closeEvent = new CustomEvent(
            'close'
        );
        this.dispatchEvent(closeEvent);
    }


}