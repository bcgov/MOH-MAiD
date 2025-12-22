import { LightningElement, wire, api } from 'lwc';
import { deleteRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

//Apex Class Controllers
import getRelatedNotes from '@salesforce/apex/ICY_Notes_Documents_Controller.getRelatedNotes';
import getUserProfileName from '@salesforce/apex/YTS_Notes_Documents_Controller.getUserProfileName';
//Custom Labels
import ICY_ErrorRetrievingNotes from '@salesforce/label/c.ICY_ErrorRetrievingNotes';
import ICY_NoteDeleted from '@salesforce/label/c.ICY_NoteDeleted';


export default class iCY_NotesComponent extends LightningElement {
    @api parentRecordId;
    @api objectApiName;
    @api adminNotes = false;

    showSpinner = false;
    subjectLabel = 'Subject'
    filtervalue = '';
    //Create Edit Note
    createEdit = false
    editNoteType = false
    editAllAsOwner  = false
    editOtherAsOwner  = false
    noteId;
    subjectOptions = [];
    isCase = false;
    deleteConfirm = false;
    sortDirection = false;
    notes;
    isSupervisor = false;

    caseSubjectOptions = [
        {label:'Session Note' , value: 'Session Note'},
        {label:'Supervision Note' , value: 'Supervision Note'},
        {label:'Critical Incident' , value: 'Critical Incident'},
        {label:'Other' , value: 'Other'},
        {label:'Contact with referring partner' , value: 'Contact with referring partner'},
        {label:'Contact with parent/caregiver/guardian:' , value: 'Contact with parent/caregiver/guardian:'},
        {label:'Contact with child/youth' , value: 'Contact with child/youth'},
        {label:'Contact with ICY team member organization' , value: 'Contact with ICY team member organization'},
        {label:'External referrals' , value: 'External referrals'},
        {label:'Contact with external organization' , value: 'Contact with external organization'},
        {label:'ICY intake/waitlist' , value: 'ICY intake/waitlist'}
    ];

    get newNoteLabel(){
        return this.adminNotes?'New Admin Note':'New Note';
    }

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
        console.log('recordId>>>'+this.parentRecordId);
        getRelatedNotes({ recordId: this.parentRecordId, sortDirection: this.sortDirection, filter: this.filtervalue, adminNotes: this.adminNotes})
        .then(result => {
            this.showSpinner = false;
            if(result && result.length > 0){
                this.notes = [];
                this.notes = result;
                if(this.objectApiName == 'Case')
                {
                    this.isCase = true;
                }
            }else{
                this.notes = null;
            }
            console.log('$$ Result: ', result);
        }).catch(error => {
            this.showSpinner = false;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: ICY_ErrorRetrievingNotes,
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
        this.editNoteType = false
        this.editAllAsOwner  = false
        this.editOtherAsOwner  = false
        this.noteId = '';
        this.init();
    }

    /**
     * Open Create Edit Modal
     */
    addNote(){
        this.createEdit = true;
        this.editNoteType = true
        this.editAllAsOwner  = true
        this.editOtherAsOwner  = true
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
    editNoteTypePL(event){
        this.noteId = event.target.dataset.recordId;
        console.log('$$ Selected Note id: ', this.noteId);
        this.editNoteType = true ;
        this.editAllAsOwner  = false
        this.editOtherAsOwner  = false
       
        }

      /**
     * Edit Note
     */
    editAllAsOwnerE(event){
        this.noteId = event.target.dataset.recordId;
        console.log('$$ Selected Note id: ', this.noteId);
       // this.editNotes = true;
       this.editNoteType = false ;
       this.editAllAsOwner  = true
       this.editOtherAsOwner  = false
       
        }

          /**
     * Edit Note
     */
    editOtherAsOwnerE(event){
        this.noteId = event.target.dataset.recordId;
        console.log('$$ Selected Note id: ', this.noteId);
       // this.editNotes = true;
       this.editNoteType = false ;
       this.editAllAsOwner  = false
       this.editOtherAsOwner  = true
       
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
                    message: ICY_NoteDeleted ,
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