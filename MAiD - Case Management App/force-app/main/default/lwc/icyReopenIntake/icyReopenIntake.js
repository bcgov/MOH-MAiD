import { LightningElement,api,wire,track } from 'lwc';
import { updateRecord } from 'lightning/uiRecordApi'; 
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation'; 
import { CurrentPageReference } from 'lightning/navigation';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import STATUS_FIELD from '@salesforce/schema/Intake__c.Status__c';
import SPECIFIC_FIELD from '@salesforce/schema/Intake__c.ICY_Assigned_To__c';
const fields = [STATUS_FIELD, SPECIFIC_FIELD];


export default class IcyReopenIntake extends NavigationMixin(LightningElement)   {
 recordId;
 referralObj;
 assignedtoFieldValue;

    @wire(CurrentPageReference)
    pageRef;
  
   
    @wire(getRecord, { recordId: '$recordId', fields })
    IntakeRecord({ error, data }) {
     if (data) {
        this.assignedtoFieldValue = getFieldValue(data, SPECIFIC_FIELD);
        this.updateStatus();        
     } else if (error) {
         console.error('Error fetching record:', error);
     } else {
         // Optional: handle the case where neither error nor data is available
         console.log('No data or error yet');
    }
    }

    connectedCallback() {
        this.recordId= this.pageRef && this.pageRef.state ? this.pageRef.state.recordId : null;
    }
   

    updateStatus() {                 
         let statusValue = '';          
         if( this.assignedtoFieldValue !== undefined  &&  this.assignedtoFieldValue !== null  &&   this.assignedtoFieldValue !== '' ) {
             statusValue = 'In Progress'; // Set desired status value
         } else {
             statusValue = 'Not Started';
         }
     
         const fields = {};
         fields['Id'] = this.recordId;
         fields[STATUS_FIELD.fieldApiName] = statusValue;
         fields['ICY_Closed_By__c']= '';
         fields['Closed_Reason__c']= '';
         fields['ICY_Rationale__c']= '';
         fields['ICY_Reopened_Date__c']=new Date().toISOString().slice(0, 10);
        
     
         const recordInput = { fields };
     
         updateRecord(recordInput)
             .then(() => {
                 this.dispatchEvent(
                     new ShowToastEvent({
                         title: 'Success',
                         message: 'Intake reopened',
                         variant: 'success'
                     })
                 );
                 this.closeQuickAction();
             })
             .catch(error => {
                 this.dispatchEvent(
                     new ShowToastEvent({
                         title: 'Error updating status',
                         message: error.body.message,
                         variant: 'error'
                     })
                 );
             });
     }
     
     closeQuickAction() {
         this.dispatchEvent(new CloseActionScreenEvent());
     }
}