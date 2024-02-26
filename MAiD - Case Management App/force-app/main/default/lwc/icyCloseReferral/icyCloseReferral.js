import { LightningElement, api, wire, track } from 'lwc';

import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, updateRecord } from 'lightning/uiRecordApi';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';

import ID_FIELD from '@salesforce/schema/Referral__c.Id';
import REASON_FIELD from '@salesforce/schema/Referral__c.Referral_Close_Reason__c';
import RATIONALE_FIELD from '@salesforce/schema/Referral__c.ICY_Rationale_For_Closure__c';
import STATUS_FIELD from '@salesforce/schema/Referral__c.Status__c';
//Custom Labels
import ICY_ReferralClosedSuccessfully from '@salesforce/label/c.ICY_ReferralClosedSuccessfully';
import ICY_ReviewTheErrors from '@salesforce/label/c.ICY_ReviewTheErrors';
import ICY_ErrorClosingReferral from '@salesforce/label/c.ICY_ErrorClosingReferral';



const FIELDS = [REASON_FIELD, RATIONALE_FIELD];

const CLOSED_STATUS = 'Closed';
const SUCCESS_MESSAGE = ICY_ReferralClosedSuccessfully;
const ERROR_MESSAGE = ICY_ReviewTheErrors;
const UNKNOWN_ERROR_MESSAGE = ICY_ErrorClosingReferral;
const LOST_ACCESS_ERROR_MESSAGE = 'INSUFFICIENT_ACCESS';
const LOST_ACCESS_ERROR_MESSAGE2 = 'Not Found';
const LOST_ACCESS_ERROR_MESSAGE3 = 'INSUFFICIENT_ACCESS_OR_READONLY';
const LOST_ACCESS_ERROR_MESSAGE4 = 'NOT_FOUND';
export default class IcyCloseReferral extends NavigationMixin(LightningElement) {
  @api recordId;
  @api objectApiName;

  @wire(getObjectInfo, { objectApiName: '$objectApiName' })
  referralInfo;

  @wire(getPicklistValues, { recordTypeId: '012000000000000AAA', fieldApiName: REASON_FIELD })
  reasonPicklistValues;

  @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
  referral;

  title = 'Close Referral';
  spinnerAltText = 'Saving';
  cancelButton = 'Cancel';
  saveButton = 'Save';
  reasonsPlaceholder = '--None--';

  showSpinner = false;

  get reasonFieldLabel() {
    return this.referralInfo.data?.fields[REASON_FIELD.fieldApiName].label;
  }

  get rationaleFieldLabel() {
    return this.referralInfo.data?.fields[RATIONALE_FIELD.fieldApiName].label;
  }

  get rationaleFieldMaxLength() {
    return this.referralInfo.data?.fields[RATIONALE_FIELD.fieldApiName].length;
  }

  get reasons() {
    return this.reasonPicklistValues.data?.values.map((r) => ({ label: r.label, value: r.value }));
  }

  handleCancel() {
    this.dispatchEvent(new CloseActionScreenEvent());
  }

  async handleSave() {
    this.showSpinner = true;

    const allValid = [...this.template.querySelectorAll('.field')].reduce(
      (validSoFar, inputFields) => {
        inputFields.reportValidity();
        return validSoFar && inputFields.checkValidity();
      },
      true
    );

    if (allValid) {
      const fields = {};
      fields[ID_FIELD.fieldApiName] = this.recordId;
      fields[STATUS_FIELD.fieldApiName] = CLOSED_STATUS;

      fields[REASON_FIELD.fieldApiName] = this.refs.Referral_Close_Reason__c.value;
      fields[RATIONALE_FIELD.fieldApiName] = this.refs.ICY_Rationale_For_Closure__c.value;

      const recordInput = { fields };

      try {
        await updateRecord(recordInput);
        this.handleSuccess();
      } catch (e) {
        if (e.body?.output?.errors?.[0]?.errorCode === LOST_ACCESS_ERROR_MESSAGE
          || e.body?.output?.errors?.[0]?.errorCode === LOST_ACCESS_ERROR_MESSAGE3
          || e.errorCode === LOST_ACCESS_ERROR_MESSAGE2
          || e.body.errorCode === LOST_ACCESS_ERROR_MESSAGE2
          || e.body.errorCode === LOST_ACCESS_ERROR_MESSAGE4) {
          this.handleSuccess();
        } else {
          this.dispatchEvent(
            new ShowToastEvent({
              title: UNKNOWN_ERROR_MESSAGE,
              message: error.body.message,
              variant: 'error',
            })
          );
        }
      } finally {
        this.showSpinner = false;
      }
    } else {
      this.showSpinner = false;
      this.dispatchEvent(
        new ShowToastEvent({
          message: ERROR_MESSAGE,
          variant: 'error',
        })
      );
    }
  }

  handleSuccess() {
    this.dispatchEvent(new CloseActionScreenEvent());
    this.dispatchEvent(
      new ShowToastEvent({
        message: SUCCESS_MESSAGE,
        variant: 'success',
      })
    );
    this[NavigationMixin.Navigate]({
      type: 'standard__objectPage',
      attributes: {
        objectApiName: this.objectApiName,
        actionName: 'home',
      },
    });
  }
}
