import { LightningElement, api , track} from 'lwc';
import upsertNote from '@salesforce/apex/ICY_Notes_Documents_Controller.upsertNote';
import getNote from '@salesforce/apex/ICY_Notes_Documents_Controller.getNote';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import YTS_Interview_Generic_Validation_Msg from '@salesforce/label/c.YTS_Interview_Generic_Validation_Msg'
//Constants
const RESTRICTED_DESC = ' Restricted: Only the note writer, Program Leaders and Clinical team members assigned to this case can view.';
const COLLAB_DESC = 'Collaborative: Only assigned team members (Clinical and Non-Clinical), Admin and Program Leaders can view.';

export default class icyCreateEditNotes extends LightningElement {

    @api parentRecordId;
    @api windowTitle;
    @api recordId;
    @api objectApiName;
    @api adminNotes = false;
    @api disableNotes ;

    showSpinner = false;
    subjectOptions = [];
    typeDesc;
    showOtherSubject = false;
    showOtherModeLocation = false;
    showOtherTeamMember = false;
    note={
        Description__c:'',
        Referral_Subject__c: '',
        Other__c:'',
        Other_Team_Member__c:'',
        Mode_Location__c:'',
        Other_Mode_Location__c:'',
        Attendees__c:'',
        Length_of_Meeting__c:'',
        ICY_Meeting_Date__c:''
    };
    isCase = false;
    noteType;
    @api caseSubjectOptions;
    noteTypeDisabled = false;

    get intakeSubjectOptions(){
        return [
            {label:'Contact with parent/caregiver/guardian:' , value: 'Contact with parent/caregiver/guardian:'},
            {label:'Contact with child/youth' , value: 'Contact with child/youth'},
            {label:'Contact with ICY team member organization' , value: 'Contact with ICY team member organization'},
            {label:'Contact with external organization' , value: 'Contact with external organization'},
            {label:'ICY intake/waitlist' , value: 'ICY intake/waitlist'},
            {label:'Other' , value: 'Other'}
        ];
    }


    get referralSubjectOptions(){
        return [
            {label:'Contact with referring partner' , value: 'Contact with referring partner'},
            {label:'Contact with parent/caregiver/guardian:' , value: 'Contact with parent/caregiver/guardian:'},
            {label:'Contact with child/youth' , value: 'Contact with child/youth'},
            {label:'Contact with ICY team member organization' , value: 'Contact with ICY team member organization'},
            {label:'External referrals' , value: 'External referrals'},
            {label:'Other' , value: 'Other'}
        ];
    }

    get noteTypeOptions(){
        return [
            {label: 'Restricted', value: 'Restricted'},
            {label: 'Collaborative', value: 'Collaborative'}
        ]
    }

    get teamMembers(){
        return [
            {label: 'Program Leader', value: 'Program Leader'},
            {label: 'ICY Clinical Counsellor', value: 'ICY Clinical Counsellor'},
            {label: 'Substance Use or Concurrent Clinician', value: 'Substance Use or Concurrent Clinician'},
            {label: 'CYMH Clinician', value: 'CYMH Clinician'},
            {label: 'Youth Peer Support', value: 'Youth Peer Support'},
            {label: 'Family Peer Support', value: 'Family Peer Support'},
            {label: 'Indigenous Support', value: 'Indigenous Support'},
            {label: 'Other', value: 'Other'}
        ]
    }

    get modeLocations(){
        return [
            {label: 'Email', value: 'Email'},
            {label: 'Telephone', value: 'Telephone'},
            {label: 'Office', value: 'Office'},
            {label: 'Outreach', value: 'Outreach'},
            {label: 'Video Conferencing', value: 'Video Conferencing'},
            {label: 'Other', value: 'Other'}
        ]
    }

    get isNoteEditDisabled(){
       return this.disableNotes;
    }

    get today() {
        var d = new Date();
        return d.getFullYear() + '-' + (d.getMonth() + 1) + '-' + d.getDate();
    }
    /**
     * Connected Call Back
     */
    connectedCallback(){
        console.log('$$ parentRecordId: ', this.parentRecordId)
        if(!this.recordId){
            this.windowTitle = 'Add New Note';
        }
        else{
            this.windowTitle = 'Edit Note';
            getNote({recordId: this.recordId}).then(result=>{
                console.log('$$ Result, ', result);
                this.note = result;
                this.noteType = result.Notes_Type__c;
                 if(result.Notes_Type__c == 'Restricted')
                     this.typeDesc = RESTRICTED_DESC;
                 else if(result.Notes_Type__c == 'Collaborative')
                     this.typeDesc = COLLAB_DESC;
                if(result.Subject__c == 'Other') this.showOtherSubject = true;
                if(result.Mode_Location__c == 'Other') this.showOtherModeLocation = true;
                if(result.Team_Member__c == 'Other') this.showOtherTeamMember = true;
                }).catch(error=>{
                console.error('$$ Error: ', error);
            })
        }
        if(this.objectApiName){
            if(this.objectApiName == 'Referral__c')
                this.subjectOptions = this.referralSubjectOptions
            else if(this.objectApiName == 'Intake__c')
            this.subjectOptions = this.intakeSubjectOptions
            else if(this.objectApiName == 'Case'){
                this.isCase = true;
                this.teamMemberOptions = this.teamMembers;
                this.modeLocationOptions = this.modeLocations;
                this.subjectOptions = this.caseSubjectOptions;
            }
        }

    }


    /**
     * Handle Change
     */
    handleChange(event){
        if (event.target.name) {
            switch (event.target.name) {
                case 'Referral_Subject__c':
                    this.note.Referral_Subject__c = event.target.value;
                    this.noteTypeDisabled = false;
                    if(event.target.value == 'Other'){
                        this.showOtherSubject = true;
                    }else{
                        if(event.target.value == 'Case Consultation' || event.target.value == 'Case Review'){
                            this.noteType = 'Restricted';
                            this.typeDesc = RESTRICTED_DESC;
                            this.noteTypeDisabled = true;
                        }
                        this.note.Other__c = '';
                        this.showOtherSubject = false;
                    }
                    break;
                case 'Notes_Type__c':
                    this.noteType = event.target.value;
                    if(event.target.value == 'Restricted')
                        this.typeDesc = RESTRICTED_DESC;
                    else if(event.target.value == 'Collaborative')
                        this.typeDesc = COLLAB_DESC;
                    break;
                case 'Description__c':
                    this.note.Description__c = event.target.value;
                    break;
                case 'ICY_Meeting_Date__c':
                    this.note.ICY_Meeting_Date__c = event.target.value;
                    break;
                case 'Other__c':
                    this.note.Other__c = event.target.value;
                    break;
                case 'Team_Member__c':
                    if(event.target.value == 'Other'){
                        this.showOtherTeamMember = true;
                    }else{
                        this.showOtherTeamMember = false;
                    }
                    this.note.Team_Member__c = event.target.value;
                    break;
                case 'Mode_Location__c':
                    if(event.target.value == 'Other'){
                        this.showOtherModeLocation = true;
                    }else{
                        this.showOtherModeLocation = false;
                    }
                    this.note.Mode_Location__c = event.target.value;
                    break;
                case 'Other_Mode_Location__c':
                        this.note.Other_Mode_Location__c = event.target.value;
                        break;
                case 'Other_Team_Member__c':
                    this.note.Other_Team_Member__c = event.target.value;
                    break;
                case 'Attendees__c':
                    this.note.Attendees__c = event.target.value;
                    break;
                case 'Length_of_Meeting__c':
                  this.note.Length_of_Meeting__c = event.target.value;
                  break;
            }
        }
    }

    //Close Modal
    closeModal() {
        const closeEvent = new CustomEvent(
            'close'
        );
        this.dispatchEvent(closeEvent);
    }


    //Save Note
    handleSave(){
        this.showSpinner = true;
        if(this.adminNotes) this.noteType = 'Administrative Notes'
        else if(!this.noteType) this.noteType = 'Collaborative';
        upsertNote({note: this.note, recordId: this.parentRecordId, noteId: this.recordIds,noteType: this.noteType}).then(result =>{
            if(result)
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Notes Updated Successfully',
                    variant: 'success',
                }),
            );
            this.showSpinner = false;
            this.closeModal();
        }).catch(error=>{
            this.showSpinner = false;
            console.error('$$ Error saving notes: ', error);
        });

    }

    validateAndSave(){
        let isValid = true;
        let inputFields = this.template.querySelectorAll('.validate');
        inputFields.forEach(inputField => {
            if (!inputField.checkValidity()) {
                inputField.reportValidity();
                isValid = false;
            }
        });

        if ((isValid) || (this.disableNotes)){
            this.handleSave();
        }else{
            const evt = new ShowToastEvent({
                title: YTS_Interview_Generic_Validation_Msg,
                variant: 'error'
            });
            this.dispatchEvent(evt);
        }
    }

    //close Modal on Click on Esc
    handleKeyDown(event) {
        if(event.code == 'Escape') {
            this.closeModal();
            event.preventDefault();
            event.stopImmediatePropagation();
        }
    }

}