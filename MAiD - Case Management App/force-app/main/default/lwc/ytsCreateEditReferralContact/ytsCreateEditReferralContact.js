import { api, LightningElement, wire, track } from 'lwc';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import CASE_CONTACT from '@salesforce/schema/Case_Contact__c';
import REFERRAL from '@salesforce/schema/Referral__c';
import getReferralContact from '@salesforce/apex/YTS_Referral_Controller.getReferralContact';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { createRecord, updateRecord } from 'lightning/uiRecordApi';
//CASE CONTACT FIELDS
import PREF_METHOD_CONTACT from '@salesforce/schema/Case_Contact__c.Preferred_method_of_contact__c';
import RELATIONS from '@salesforce/schema/Case_Contact__c.Relationship_Subtype__c';
import ID_FIELD from '@salesforce/schema/Case_Contact__c.Id';
import FIRST_NAME_FIELD from '@salesforce/schema/Case_Contact__c.Contact_Person_First_Name__c';
import LAST_NAME_FIELD from '@salesforce/schema/Case_Contact__c.Contact_Person_Last_Name__c';
import HOME_PHONE_FIELD from '@salesforce/schema/Case_Contact__c.Contact_Person_Home_Phone_Number__c';
import WORK_PHONE_FIELD from '@salesforce/schema/Case_Contact__c.Contact_Person_Work_Phone_Number__c';
import WP_EX_FIELD from '@salesforce/schema/Case_Contact__c.Contact_Person_Work_Phone_Extension__c';
import CELL_FIELD from '@salesforce/schema/Case_Contact__c.Contact_Person_Cell_Phone_Number__c';
import EMAIL_FIELD from '@salesforce/schema/Case_Contact__c.Contact_Person_Email_Address__c';
import ADDRESS_FIELD from '@salesforce/schema/Case_Contact__c.Mailing_Address_Line1__c';
import CITY_FIELD from '@salesforce/schema/Case_Contact__c.Mailing_Address_City__c';
import POSTAL_FIELD from '@salesforce/schema/Case_Contact__c.Mailing_Address_Postal_Code__c';
import OTHER_REL_FIELD from '@salesforce/schema/Case_Contact__c.Other_Relationship__c';
import REF_ID_FIELD from '@salesforce/schema/Case_Contact__c.Referral__c';
import PROVINCE_FIELD from '@salesforce/schema/Case_Contact__c.Mailing_Address_Province__c';
import CONTACT_TYPE from '@salesforce/schema/Case_Contact__c.Contact_Type__c';
import PRIMARY_CONTACT_IND from '@salesforce/schema/Referral__c.Primary_Contact_Is_Individual_Indicator__c';
import REFERRAL_ID from '@salesforce/schema/Referral__c.Id';

//Custom Labels
import ICY_EitherIndividualHomePhone from '@salesforce/label/c.ICY_EitherIndividualHomePhone';
import ICY_MissingRequiredFields from '@salesforce/label/c.ICY_MissingRequiredFields';
import ICY_ReferralContactCreated from '@salesforce/label/c.ICY_ReferralContactCreated';
import ICY_ReferralContactUpdated from '@salesforce/label/c.ICY_ReferralContactUpdated';





export default class YtsCreateEditReferralContact extends LightningElement {
    @track contact = {
        Id: '',
        Contact_Person_First_Name__c: '',
        Contact_Person_Last_Name__c: '',
        Preferred_method_of_contact__c: '',
        Contact_Person_Home_Phone_Number__c: '',
        Contact_Person_Work_Phone_Number__c: '',
        Contact_Person_Work_Phone_Extension__c: '',
        Contact_Person_Cell_Phone_Number__c: '',
        Contact_Person_Email_Address__c: '',
        Mailing_Address_Line1__c: '',
        Mailing_Address_City__c: '',
        Mailing_Address_Postal_Code__c: '',
        Mailing_Address_Province__c: 'BC',
        Relationship_Subtype__c: '',
        Other_Relationship__c: '',
        Referral__c: ''
    };

    @api primarycontact;
    @api action;
    windowTitle;
    prefMethodContactOption = [];
    step1 = true;
    step2 = false;
    @api referralId = 'a0s1f000000CrNEAA0';
    @api showPreferedMethodOfCon;
    @api contactId;
    @api contactType = '';
    isOtherContact = false;
    disabled = false;

    //Fetch Picklist values
    @wire(getObjectInfo, { objectApiName: CASE_CONTACT }) caseContact;
    @wire(getPicklistValues, {
        recordTypeId: '$caseContact.data.defaultRecordTypeId',
        fieldApiName: RELATIONS
    }) relationOptions;

    @wire(getPicklistValues, { recordTypeId: '$caseContact.data.defaultRecordTypeId', fieldApiName: PREF_METHOD_CONTACT })
    prefData({ error, data }) {
        if (data) {
            this.prefMethodContactOption = data.values.map(objPL => {
                return {
                    label: `${objPL.label}`,
                    value: `${objPL.value}`
                };
            });
        } else if (error) {
            console.error(JSON.stringify(error));
        }
    }


    connectedCallback() {
        if (this.action == 'update') {
            this.windowTitle = 'Update Contact';
            this.step1 = false;
            this.step2 = true;
            if (this.contactId) {
                getReferralContact({ contactId: this.contactId }).then((result) => {
                    console.log('$$ Edit con result: ', result);
                    this.contact = result;
                    this.contact.Id = result.Id
                    this.contact.Contact_Person_First_Name__c = result.Contact_Person_First_Name__c ? result.Contact_Person_First_Name__c : ''
                    this.contact.Contact_Person_Last_Name__c = result.Contact_Person_Last_Name__c ? result.Contact_Person_Last_Name__c : ''
                    this.contact.Preferred_method_of_contact__c = result.Preferred_method_of_contact__c ? result.Preferred_method_of_contact__c : ''
                    this.contact.Contact_Person_Home_Phone_Number__c = result.Contact_Person_Home_Phone_Number__c ? result.Contact_Person_Home_Phone_Number__c : ''
                    this.contact.Contact_Person_Work_Phone_Number__c = result.Contact_Person_Work_Phone_Number__c ? result.Contact_Person_Work_Phone_Number__c : ''
                    this.contact.Contact_Person_Work_Phone_Extension__c = result.Contact_Person_Work_Phone_Extension__c ? result.Contact_Person_Work_Phone_Extension__c : ''
                    this.contact.Contact_Person_Cell_Phone_Number__c = result.Contact_Person_Cell_Phone_Number__c ? result.Contact_Person_Cell_Phone_Number__c : ''
                    this.contact.Contact_Person_Email_Address__c = result.Contact_Person_Email_Address__c ? result.Contact_Person_Email_Address__c : ''
                    this.contact.Mailing_Address_Line1__c = result.Mailing_Address_Line1__c ? result.Mailing_Address_Line1__c : ''
                    this.contact.Mailing_Address_City__c = result.Mailing_Address_City__c ? result.Mailing_Address_City__c : ''
                    this.contact.Mailing_Address_Postal_Code__c = result.Mailing_Address_Postal_Code__c ? result.Mailing_Address_Postal_Code__c : ''
                    this.contact.Mailing_Address_Province__c = result.Mailing_Address_Province__c ? result.Mailing_Address_Province__c : 'BC'
                    this.contact.Relationship_Subtype__c = result.Relationship_Subtype__c ? result.Relationship_Subtype__c : ''
                    if(this.contact.Relationship_Subtype__c == 'Other') this.isOtherContact = true;
                    else this.isOtherContact = false;
                    this.contact.Other_Relationship__c = result.Other_Relationship__c ? result.Other_Relationship__c : ''
                    this.contact.Referral__c = result.Referral__c
                }).catch(error => {
                    console.error('$$ ERROR RETRIEVING CONTACT: ', error);
                });
            }
        } else {
            this.windowTitle = 'Add Contact';
        }
    }

    closeModal() {
        const closeEvent = new CustomEvent(
            'close'
        );
        this.dispatchEvent(closeEvent);
    }

    handleChange(event) {
        if (event.target.name) {
            switch (event.target.name) {
                case 'Relationship_Subtype__c':
                    this.contact.Relationship_Subtype__c = event.target.value;
                    this.isOtherContact = (event.target.value == 'Other');
                    break;
                case 'Contact_Person_First_Name__c':
                    this.contact.Contact_Person_First_Name__c = event.target.value;
                    break;
                case 'Contact_Person_Last_Name__c':
                    this.contact.Contact_Person_Last_Name__c = event.target.value;
                    break;
                case 'Contact_Person_First_Name__c':
                    this.contact.Contact_Person_First_Name__c = event.target.value;
                    break;
                case 'Contact_Person_Home_Phone_Number__c':
                    var s = ("" + event.target.value).replace(/\D/g, '');
                    var m = s.match(/^(\d{3})(\d{3})(\d{4})$/);
                    if ((!m || m != null) && s.length < 10) {
                        break;
                    }
                    var formattedPhone = (!m) ? null : "(" + m[1] + ") " + m[2] + "-" + m[3];
                    this.contact.Contact_Person_Home_Phone_Number__c = formattedPhone;
                    break;
                case 'Contact_Person_Email_Address__c':
                    this.contact.Contact_Person_Email_Address__c = event.target.value;
                    break;
                case 'Preferred_method_of_contact__c':
                    this.contact.Preferred_method_of_contact__c = event.target.value;
                    break;
                case 'Mailing_Address_Line1__c':
                    this.contact.Mailing_Address_Line1__c = event.target.value;
                    break;
                case 'Mailing_Address_City__c':
                    this.contact.Mailing_Address_City__c = event.target.value;
                    break;
                case 'Mailing_Address_Postal_Code__c':
                    this.contact.Mailing_Address_Postal_Code__c = event.target.value;
                    break;
                case 'Other_Relationship__c':
                    this.contact.Other_Relationship__c = event.target.value;
                    break;
            }
        }
    }

    handleNext() {
        if (this.step1) {
            this.step1 = false
            this.step2 = true;
        }
    }

    handlePrevious() {
        if (this.step2) {
            this.step2 = false;
            this.step1 = true;
        }
    }

    isInputValid() {
        let isValid = true;
        let inputFields = this.template.querySelectorAll('.validate');
        inputFields.forEach(inputField => {
            if (!inputField.checkValidity()) {
                inputField.reportValidity();
                isValid = false;
            }
        });
        return isValid;
    }

    handleSave() {

        this.disableButton();
        if (!this.isInputValid()) {
            const evt = new ShowToastEvent({
                title: ICY_MissingRequiredFields,
                variant: 'error'
            });
            this.dispatchEvent(evt);
            this.disabled=false;
            return;
        }
        if ((this.contact.Preferred_method_of_contact__c == 'Email' && !this.contact.Contact_Person_Email_Address__c) || ((this.contact.Preferred_method_of_contact__c == 'Phone' || this.contact.Preferred_method_of_contact__c == 'Text') && !this.contact.Contact_Person_Home_Phone_Number__c)) {
            const evt = new ShowToastEvent({
                title: ICY_EitherIndividualHomePhone,
                variant: 'error'
            });
            this.dispatchEvent(evt);
            this.disabled=false;
            return;
        }

        this.createOrModifyContact()


    }

    disableButton(){
        this.disabled =  true;
    }


    createOrModifyContact() {
        const fields = {};
        fields[FIRST_NAME_FIELD.fieldApiName] = this.contact.Contact_Person_First_Name__c;
        fields[LAST_NAME_FIELD.fieldApiName] = this.contact.Contact_Person_Last_Name__c;
        fields[HOME_PHONE_FIELD.fieldApiName] = this.contact.Contact_Person_Home_Phone_Number__c;
        fields[WORK_PHONE_FIELD.fieldApiName] = this.contact.Contact_Person_Work_Phone_Number__c;
        fields[WP_EX_FIELD.fieldApiName] = this.contact.Contact_Person_Work_Phone_Extension__c;
        fields[CELL_FIELD.fieldApiName] = this.contact.Contact_Person_Cell_Phone_Number__c;
        fields[EMAIL_FIELD.fieldApiName] = this.contact.Contact_Person_Email_Address__c;
        fields[ADDRESS_FIELD.fieldApiName] = this.contact.Mailing_Address_Line1__c;
        fields[CITY_FIELD.fieldApiName] = this.contact.Mailing_Address_City__c;
        fields[POSTAL_FIELD.fieldApiName] = this.contact.Mailing_Address_Postal_Code__c;
        fields[PROVINCE_FIELD.fieldApiName] = this.contact.Mailing_Address_Province__c;
        fields[RELATIONS.fieldApiName] = this.contact.Relationship_Subtype__c;
        fields[OTHER_REL_FIELD.fieldApiName] = this.contact.Other_Relationship__c?this.contact.Other_Relationship__c:'Other';
        fields[REF_ID_FIELD.fieldApiName] = this.referralId;
        fields[PREF_METHOD_CONTACT.fieldApiName] = this.contact.Preferred_method_of_contact__c;
        fields[CONTACT_TYPE.fieldApiName] = this.contactType;

        if (this.contactId) {
            fields[ID_FIELD.fieldApiName] = this.contactId;
            const recrdInput = { fields };
            updateRecord(recrdInput).then(() => {
                console.log('$$ Record Modified, ');
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: ICY_ReferralContactUpdated ,
                        variant: 'success',
                    }),
                );
                this.dispatchEvent(new CustomEvent('closemodal'));
            })
        } else {
            const recordInput = { apiName: CASE_CONTACT.objectApiName, fields };
            createRecord(recordInput).then(result => {
                this.contact.Id = result.id;
                if (this.contactType == 'Primary') {
                    const fields = {};
                    fields[PRIMARY_CONTACT_IND.fieldApiName] = false;
                    fields[REFERRAL_ID.fieldApiName] = this.referralId;
                    const referalInput = { fields };
                    updateRecord(referalInput).then(() => {
                        this.dispatchEvent(
                            new ShowToastEvent({
                                title: 'Success',
                                message: ICY_ReferralContactCreated,
                                variant: 'success',
                            }),
                        );
                        this.dispatchEvent(new CustomEvent('closemodal'));
                    }).catch(error => {
                        console.error('ERROR : ', JSON.stringify(error));
                    });
                } else {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Success',
                            message: ICY_ReferralContactCreated,
                            variant: 'success',
                        }),
                    );
                    this.dispatchEvent(new CustomEvent('closemodal'));
                }
            }).catch(error => {
                console.error('$$$$ ERROR : ', JSON.stringify(error));
            });
        }
    }
}