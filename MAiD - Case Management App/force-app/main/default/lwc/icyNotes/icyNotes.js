import { LightningElement, wire, api } from 'lwc';
import { deleteRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

//Apex Class Controllers
import getRelatedNotes from '@salesforce/apex/ICY_Notes_Documents_Controller.getRelatedNotes';
import getUserProfileName from '@salesforce/apex/ICY_Notes_Documents_Controller.getUserProfileName';

export default class IcyNotes extends LightningElement {
    @api objectApiName;
    @api parentRecordId
    showSpinner = false;
    @api newNoteLabel = 'New Note'
    @api subjectLabel = 'Subject'
    @api filtervalue = '';
    //Create Edit Note
    createEdit = false
    noteId;
    subjectOptions = [];
    isCase = false;
    deleteConfirm = false;
    sortDirection = false;
    notes;
    isSupervisor = false;
    caseSubjectOptions = [];

    /**
     * Connected Call Back
     */
    connectedCallback(){

        this.init();
    }


    /**
     * Component Initialize
     */
    init(){
        this.showSpinner = true;
        getRelatedNotes({ recordId: this.parentRecordId, sortDirection: this.sortDirection, filter: this.filtervalue })
        .then(result => {
            if(result && result.length > 0){
                this.notes = [];
                this.notes = result;
                console.log('Notes',JSON.stringify(result));
                if(this.objectApiName == 'Case')
                {
                    this.isCase = true;
                }
            }else{
                this.notes = null;
            }
            console.log('$$ Result: ', result);
            return getUserProfileName();
        }).then(result =>{
            if(result){
                if(result == 'STADD Director' || result == 'YT Team Lead' || result == 'System Administrator'){
                    this.caseSubjectOptions = [
                        {label:'Contact with: Guardian' , value: 'Contact with: Guardian'},
                        {label:'Contact with: Youth' , value: 'Contact with: Youth'},
                        {label:'Contact with: Partner' , value: 'Contact with: Partner'},
                        {label:'Contact with: Caregiver' , value: 'Contact with: Caregiver'},
                        {label:'Plan Progress' , value: 'Plan Progress'},
                        {label:'Case Alert' , value: 'Case Alert'},
                        {label:'Meeting Facilitated' , value: 'Meeting Facilitated'},
                        {label:'Meeting Attended' , value: 'Meeting Attended'},
                        {label:'Case Consultation' , value: 'Case Consultation'},
                        {label:'Case Review' , value: 'Case Review'},
                        {label:'Other' , value: 'Other'}
                    ];
                }else{
                    this.caseSubjectOptions = [
                        {label:'Contact with: Guardian' , value: 'Contact with: Guardian'},
                        {label:'Contact with: Youth' , value: 'Contact with: Youth'},
                        {label:'Contact with: Partner' , value: 'Contact with: Partner'},
                        {label:'Contact with: Caregiver' , value: 'Contact with: Caregiver'},
                        {label:'Plan Progress' , value: 'Plan Progress'},
                        {label:'Case Alert' , value: 'Case Alert'},
                        {label:'Meeting Facilitated' , value: 'Meeting Facilitated'},
                        {label:'Meeting Attended' , value: 'Meeting Attended'},
                        {label:'Other' , value: 'Other'}
                    ];
                }
            }
            this.showSpinner = false;
        }).catch(error => {
            this.showSpinner = false;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Error Retrieving notes',
                    variant: 'error'
                })
            );
            console.error('$$ Error retrieving Notes: ', error);
        });
    }

    /**
     * Refresh Page
     */
    refresh(){
        this.filtervalue = '';
        this.init();
    }

    /**
     * Close Create Edit Modal
     */
    closeModal(){
        this.createEdit = false;
        this.noteId = '';
        this.init();
    }

    /**
     * Open Create Edit Modal
     */
    addNote(){
        this.createEdit = true;
    }

    /**
     * Sort Case Notes List
     */
    sortList(){
        this.sortDirection = !this.sortDirection;
        this.init();
    }
    /**
     * Edit Note
     */
    editNote(event){
        this.noteId = event.target.dataset.recordId;
        console.log('$$ Selected Note id: ', this.noteId);
        this.createEdit = true;
    }

    /**
     * Delete Note
     * @param {*} event
     */
    handleDelete(event){
        this.noteId = event.target.dataset.recordId;
        console.log('$$ Sleected note to delete: ', this.noteId)
        this.deleteConfirm = true;

    }

    /**
     * delete confirmation
     */
     deleteConfirmation(){
        deleteRecord(this.noteId).then(()=>{
            this.noteId = null;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Note Deleted',
                    variant: 'success'
                })
            );
            this.closeConfirmation();
        }).catch(error=>{
            console.error('$$ ERror deleting: ', error)
        })
     }

     /**
      * close confirmation modal
      */
    closeConfirmation(){
        this.deleteConfirm = false;
        this.init();
    }
    handleChange(event){
        this.filtervalue = event.detail.value;
        this.init();
    }

}