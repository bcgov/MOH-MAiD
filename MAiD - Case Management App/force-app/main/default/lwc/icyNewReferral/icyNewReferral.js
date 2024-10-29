import { LightningElement, track, wire } from 'lwc';
//Get Object info
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
//import object schema
import REFERRAL_OBJ from '@salesforce/schema/Referral__c';
import REFERRAL_CONTACT_OBJ from '@salesforce/schema/Case_Contact__c';
//import Referral__c object field schema
import Gender__c from '@salesforce/schema/Referral__c.Individual_Gender__c';
import RecordTypeId from '@salesforce/schema/Referral__c.RecordTypeId';
import Individual_First_Name__c from '@salesforce/schema/Referral__c.Individual_First_Name__c';
import Individual_Middle_Name__c from '@salesforce/schema/Referral__c.Individual_Middle_Name__c';
import Individual_Last_Name__c from '@salesforce/schema/Referral__c.Individual_Last_Name__c';
import Individual_Preferred_Name__c from '@salesforce/schema/Referral__c.Individual_Preferred_Name__c';
import Individual_Date_of_Birth__c from '@salesforce/schema/Referral__c.Individual_Date_of_Birth__c';
import Individual_Pronouns__c from '@salesforce/schema/Referral__c.Individual_Pronouns__c';
import Physical_Address_Line_1__c from '@salesforce/schema/Referral__c.Physical_Address_Line_1__c';
import Physical_Address_Postal_Code__c from '@salesforce/schema/Referral__c.Physical_Address_Postal_Code__c';
import Physical_Address_Province__c from '@salesforce/schema/Referral__c.Physical_Address_Province__c';
import Physical_Address_City__c from '@salesforce/schema/Referral__c.Physical_Address_City__c';
import Individual_Home_Phone_Number__c from '@salesforce/schema/Referral__c.Individual_Home_Phone_Number__c';
import Individual_Cell_Phone_Number__c from '@salesforce/schema/Referral__c.Individual_Cell_Phone_Number__c';
import Referral_Notes__c from '@salesforce/schema/Referral__c.Referral_Notes__c';
import Status__c from '@salesforce/schema/Referral__c.Status__c';
import ICY_Referred_By__c from '@salesforce/schema/Referral__c.ICY_Referred_By__c';
import ICY_Personal_Health_Number__c from '@salesforce/schema/Referral__c.ICY_Personal_Health_Number__c';
import ICY_Preferred_Method_of_Contact__c from '@salesforce/schema/Referral__c.ICY_Preferred_Method_of_Contact__c';
import ICY_Other_Phone__c from '@salesforce/schema/Referral__c.ICY_Other_Phone__c';
import ICY_If_Parent_Guardian_is_aware__c from '@salesforce/schema/Referral__c.ICY_If_Parent_Guardian_is_aware__c';
import ICY_Reason_for_Referral__c from '@salesforce/schema/Referral__c.ICY_Reason_for_Referral__c';
import Reason_for_Referral_if_Other__c from '@salesforce/schema/Referral__c.Reason_for_Referral_if_Other__c';
import ICY_Relevant_Information__c from '@salesforce/schema/Referral__c.ICY_Relevant_Information__c';
import ICY_Current_Supports__c from '@salesforce/schema/Referral__c.ICY_Current_Supports__c';
import ICY_Ethnicity__c from '@salesforce/schema/Referral__c.ICY_Ethnicity__c';
import ICY_Preferred_Language__c from '@salesforce/schema/Referral__c.ICY_Preferred_Language__c';
import ICY_Diagnosis__c from '@salesforce/schema/Referral__c.ICY_Diagnosis__c';
import ICY_Medication__c from '@salesforce/schema/Referral__c.ICY_Medication__c';
import ICY_Geographic_Area__c from '@salesforce/schema/Referral__c.ICY_Geographic_Area__c';
import ICY_Medical_Referral_Reason__c from '@salesforce/schema/Referral__c.ICY_Medical_Referral_Reason__c';
import ICY_Can_We_Leave_a_Message_On_Cell__c from '@salesforce/schema/Referral__c.ICY_Can_We_Leave_a_Message_On_Cell__c';
import ICY_Leave_a_Message_On_other_Phone__c from '@salesforce/schema/Referral__c.ICY_Leave_a_Message_On_other_Phone__c';
import ICY_Can_We_Leave_a_Message_On_Home_Phone__c from '@salesforce/schema/Referral__c.ICY_Can_We_Leave_a_Message_On_Home_Phone__c';

import Preferred_Contact_s_Name_Cell__c from '@salesforce/schema/Referral__c.Preferred_Contact_s_Name_Cell__c';
import Preferred_Contact_s_Name_Home__c from '@salesforce/schema/Referral__c.Preferred_Contact_s_Name_Home__c';
import Preferred_Contact_s_Name_Other__c from '@salesforce/schema/Referral__c.Preferred_Contact_s_Name_Other__c';

import Relationship_to_Individual_Cell__c from '@salesforce/schema/Referral__c.Relationship_to_Individual_Cell__c';
import Relationship_to_Individual_Home__c from '@salesforce/schema/Referral__c.Relationship_to_Individual_Home__c';
import Relationship_to_Individual_Other__c from '@salesforce/schema/Referral__c.Relationship_to_Individual_Other__c';

import Other_Relationship_Cell__c from '@salesforce/schema/Referral__c.Other_Relationship_Cell__c';
import Other_Relationship_Home__c from '@salesforce/schema/Referral__c.Other_Relationship_Home__c';
import Other_Relationship_Other__c from '@salesforce/schema/Referral__c.Other_Relationship_Other__c';


import ICY_Referral_For__c from '@salesforce/schema/Referral__c.ICY_Referral_For__c';
import ICY_CYMH__c from '@salesforce/schema/Referral__c.ICY_CYMH__c';
import ICY_Priority__c from '@salesforce/schema/Referral__c.ICY_Priority__c';
import ICY_Referral_Source__c from '@salesforce/schema/Referral__c.ICY_Referral_Source__c';
import ICY_Indigenous__c from '@salesforce/schema/Referral__c.ICY_Indigenous__c';
import ICY_CHILD_YOUTH_Aware__c from '@salesforce/schema/Referral__c.ICY_Child_Youth_Aware__c';
import ICY_Unknown_Address__c from '@salesforce/schema/Referral__c.ICY_Unknown_Address__c';
import ICY_Referral_Source_Description__c from '@salesforce/schema/Referral__c.ICY_Referral_Source_Description__c';
import ICY_Date_of_Referral__c from '@salesforce/schema/Referral__c.ICY_Date_of_Referral__c';
import OWNERID from '@salesforce/schema/Referral__c.OwnerId';


//Custom Labels
import ICY_NoProgramLeader from '@salesforce/label/c.ICY_NoProgramLeader';
import ICY_PleaseEnterPostalCode from '@salesforce/label/c.ICY_PleaseEnterPostalCode';

//Toast
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
//LDS
import { createRecord } from 'lightning/uiRecordApi';
//Apex Controller
import getPicklistvalues from '@salesforce/apex/ICY_Referral_Controller.getPicklistvalues';
import getRecordTypeId from '@salesforce/apex/ICY_Referral_Controller.getRecordTypeId';
import getICYQueueId from '@salesforce/apex/ICY_Referral_Controller.getICYQueueId'
import checkIfHealthNumberIsUnique from '@salesforce/apex/ICY_Referral_Controller.checkIfHealthNumberIsUnique'
import createPrimaryContact from '@salesforce/apex/ICY_Referral_Controller.createPrimaryContact'

export default class IcyNewReferral extends NavigationMixin(LightningElement) {
    openModal = false;
    showSpinner = false;
    page1 = true;
    page2 = false;
    page3 = false;
    page4 = false;
    @track referralForOptions = [];
    genderOptions;
    methodOfConOptions;
    guardianRelationOptions;
    @track medicalReferralReasonOptions = [];
    isParentAwareOptions;
    referredByName;
    referralType;
    referralAge = 0;
    isYouthReferral = false;
    showPrimaryContact = false;
    value;
    generalRecordTypeId;
    medicalRecordTypeId;
    showContactModal = false;
    icyContactRecordTypeId;
    ytsContactRecordTypeId;
    referralRecordId;
    ICY_Personal_Health_Number='';



    @track
    primaryContact = {
        Contact_Person_First_Name__c: '',
        Contact_Person_Last_Name__c: '',
        Relationship_Subtype__c: '',
        Contact_Person_Email_Address__c: '',
        Contact_Person_Home_Phone_Number__c: '',
        Other_Relationship__c: '',
        Contact_Type__c: '',
        Contact_Subtype__c: ''
    }

    @track
    referral = {
        Individual_First_Name__c: '',
        Individual_Last_Name__c: '',
        Individual_Middle_Name__c: '',
        ICY_Referred_By__c: '',
        ICY_Referral_For__c: '',
        Individual_Date_of_Birth__c: '',
        ICY_Personal_Health_Number__c: '',
        Individual_Gender__c: '',
        Individual_Pronouns__c: '',
        Physical_Address_Line_1__c: '',
        Physical_Address_Postal_Code__c: '',
        Physical_Address_City__c: '',
        ICY_Preferred_Method_of_Contact__c: '',
        ICY_Other_Phone__c: '',
        Individual_Home_Phone_Number__c: '',
        Individual_Cell_Phone_Number__c: '',
        ICY_If_Parent_Guardian_is_aware__c: '',
        ICY_CHILD_YOUTH_Aware__c: false,
        ICY_Reason_for_Referral__c: '',
        Reason_for_Referral_if_Other__c: '',
        ICY_Relevant_Information__c: '',
        ICY_Current_Supports__c: '',
        ICY_Ethnicity__c: '',
        ICY_Preferred_Language__c: '',
        ICY_Diagnosis__c: '',
        ICY_Medication__c: '',
        Referral_Notes__c: '',
        ICY_Geographic_Area__c: '',
        ICY_Medical_Referral_Reason__c: '',
        Individual_Preferred_Name__c: '',
        ICY_Can_We_Leave_a_Message_On_Cell__c: false,
        ICY_Can_We_Leave_a_Message_On_Home_Phone__c: false,
        ICY_Leave_a_Message_On_other_Phone__c: false,
        ICY_CYMH__c: '',
        ICY_Priority__c: '',
        ICY_Referral_Source__c: '',
        ICY_Indigenous__c: '',
        ICY_Unknown_Address__c: false,
        ICY_Referral_Source_Description__c: '',
        ICY_Date_of_Referral__c: '',
        OwnerId: '',
        Preferred_Contact_s_Name_Cell__c: '',
        Preferred_Contact_s_Name_Home__c: '',
        Preferred_Contact_s_Name_Other__c: '',
        Relationship_to_Individual_Cell__c: '',
        Relationship_to_Individual_Home__c: '',
        Relationship_to_Individual_Other__c: '',
        Other_Relationship_Cell__c: '',
        Other_Relationship_Home__c: ''

    };

    @track isFieldOtherCellRequired = false;
    @track isFieldOtherHomeRequired = false;
    @track isFieldOtherRequired = false;
    @track isFieldReasonForReferralifOtherRequired = false;

    //Getter Methods

    get isMedicalReferral() {
        return this.referralType == 'Professional Referral';
    }

    get isGeneralReferral() {
        return this.referralType == 'General Referral';
    }

    get referralTypeOptions() {
        return [
            { label: 'General Referral', value: 'General Referral' },
            { label: 'Professional Referral', value: 'Professional Referral' }
        ];
    }

    //Next Button Label
    get nextLabel() {
        if (this.page1) return 'Start Referral';
        if (this.page2 || this.page3) return 'Next';
        if (this.page4) return 'Submit Referral'
    }

    //Modal Header
    get modalHeader() {
        return 'New Referral'
    }

    get today() {
        var d = new Date();
        return d.getFullYear() + '-' + (d.getMonth() + 1) + '-' + d.getDate();
    }

    //Get Picklist values from Object Fields
    @wire(getObjectInfo, { objectApiName: REFERRAL_OBJ }) referralObjectSchema;
    @wire(getObjectInfo, { objectApiName: REFERRAL_CONTACT_OBJ }) referralContactObjectSchema;

    //Gender Options
    @wire(getPicklistValues, {
        recordTypeId: '$referralObjectSchema.data.defaultRecordTypeId',
        fieldApiName: Gender__c
    }) getGenderOptions({ error, data }) {
        if (data) {
            this.genderOptions = data.values.map(element => {
                return {
                    label: `${element.label}`,
                    value: `${element.value}`
                }
            })
        } else if (error) {
            console.error('$$ Error retrieving Gender Options: ', JSON.stringify(error));
        }
    }

    //Preferred Method Of Contact Options
    @wire(getPicklistvalues, {
        objectApiName: 'Referral__c',
        fieldApiName: 'ICY_Preferred_Method_of_Contact__c'
    }) getPreferredMethodOfContact({ error, data }) {
        if (data) {
            this.methodOfConOptions = [];

            for (const [key, value] of Object.entries(data)) {
                let temp = {
                    label: '',
                    value: ''
                };
                temp.label = key;
                temp.value = value;
                this.methodOfConOptions.push(temp);
            }
        } else if (error) {
            console.error('$$ Error getting Preferred METhod Of COntact options: ' + error);
        }
    }


    //Get Referral For Options
    @wire(getPicklistvalues, {
        objectApiName: 'Referral__c',
        fieldApiName: 'ICY_Referral_For__c'
    }) getReferralForOptions_1({ error, data }) {
        if (data) {
            this.referralForOptions = [];

            for (const [key, value] of Object.entries(data)) {
                let temp = {
                    label: '',
                    value: ''
                };
                temp.label = key;
                temp.value = value;
                this.referralForOptions.push(temp);
            }
        } else if (error) {
            console.error('$$ Error getting Referral For options: ' + error);
        }
    }




    //Relationship Types    
    @wire(getPicklistvalues, {
        objectApiName: 'Case_Contact__c',
        fieldApiName: 'Relationship_Subtype__c'
    }) getguardianRelationOptions({ error, data }) {
        if (data) {
            this.guardianRelationOptions = [];

            for (const [key, value] of Object.entries(data)) {
                let temp = {
                    label: '',
                    value: ''
                };
                temp.label = key;
                temp.value = value;
                this.guardianRelationOptions.push(temp);
            }
        } else if (error) {
            console.error('$$ Error getting Guardian options: ' + error);
        }
    }

    //Medial Reason Options
    @wire(getPicklistvalues, {
        objectApiName: 'Referral__C',
        fieldApiName: 'ICY_Medical_Referral_Reason__c'
    }) getMedicalReferralReasons({ error, data }) {
        if (data) {
            this.medicalReferralReasonOptions = [];

            for (const [key, value] of Object.entries(data)) {
                let temp = {
                    label: '',
                    value: ''
                };
                temp.label = key;
                temp.value = value;
                this.medicalReferralReasonOptions.push(temp);
            }
        } else if (error) {
            console.error('$$ Error getting medicalReferralReasonOptions options: ' + error);
        }
    }

    //Get ICY General RecorD TYpe Id
    @wire(getRecordTypeId, {
        objectApiName: 'Referral__c',
        recordTypeDeveloperName: 'ICY_General'
    }) getIcyGeneralRTId({ error, data }) {
        if (data) this.generalRecordTypeId = data;
        else if (error) console.error('$$ Error Retrieving Record TYpe Id: ' + JSON.stringify(error));
    }

    //Get ICY Medical RecorD TYpe Id
    @wire(getRecordTypeId, {
        objectApiName: 'Referral__c',
        recordTypeDeveloperName: 'ICY_Medical'
    }) getIcyMedicalRTId({ error, data }) {
        if (data) this.medicalRecordTypeId = data;
        else if (error) console.error('$$ Error Retrieving Record TYpe Id: ' + JSON.stringify(error));
    }

    //Contact Record Type Id
    @wire(getRecordTypeId, {
        objectApiName: 'Case_Contact__c',
        recordTypeDeveloperName: 'ICY_Case_Contact'
    }) getReferralICYRT({ error, data }) {
        if (data) this.icyContactRecordTypeId = data;
        else if (error) console.error('$$ Error Retrieving Record TYpe Id: ' + JSON.stringify(error));
    }


    //Init
    connectedCallback() {

    }

    //Handle Next Navigation
    handleNext(event) {

        window.scrollTo({ top: 0, behaviour: "smooth" });
        if (!this.isInputValid()) {
            const evt = new ShowToastEvent({
                title: 'Missing Required Fields',
                variant: 'error'
            });
            this.dispatchEvent(evt);
            return;
        }
        if (this.page1) {
            this.page1 = false;
            this.page2 = true;
            this.page3 = false;
            this.page4 = false;
        } else if (this.page2) {

            if (this.isYouthReferral) {
                this.page2 = false;
                this.page1 = false;
                this.page3 = true;
                this.page4 = false;
            }
            else {
                this.page2 = false;
                this.page1 = false;
                this.page3 = false;
                this.page4 = true;
            }
        } else if (this.page3) {
            this.page1 = false;
            this.page2 = false;
            this.page3 = false;
            this.page4 = true;
        } else if (this.page4) {
            this.saveReferral();
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
       
       
        if (((!this.referral.ICY_Referral_Source__c) ||(!this.referral.ICY_Geographic_Area__c)) && (this.page2 == true)) {
            isValid = false;
        }
        return isValid;
    }

    saveReferral() {
        this.showSpinner = true;
        const fields = {};
        let referralFor;
        let medReferralReason;
        if (this.referral.ICY_Referral_For__c) {
            for (let i = 0; i < this.referral.ICY_Referral_For__c.length; i++) {
                if (referralFor) referralFor += this.referral.ICY_Referral_For__c[i] + ';';
                else referralFor = this.referral.ICY_Referral_For__c[i] + ';'
            }
        }
        if (this.referral.ICY_Medical_Referral_Reason__c) {
            for (let i = 0; i < this.referral.ICY_Medical_Referral_Reason__c.length; i++) {
                if (medReferralReason) medReferralReason += this.referral.ICY_Medical_Referral_Reason__c[i] + ';';
                else medReferralReason = this.referral.ICY_Medical_Referral_Reason__c[i] + ';'
            }
        }


        fields[Individual_First_Name__c.fieldApiName] = this.referral.Individual_First_Name__c
        fields[Individual_Middle_Name__c.fieldApiName] = this.referral.Individual_Middle_Name__c
        fields[Individual_Last_Name__c.fieldApiName] = this.referral.Individual_Last_Name__c
        fields[Individual_Preferred_Name__c.fieldApiName] = this.referral.Individual_Preferred_Name__c
        fields[Individual_Date_of_Birth__c.fieldApiName] = this.referral.Individual_Date_of_Birth__c
        fields[Gender__c.fieldApiName] = this.referral.Individual_Gender__c
        fields[Individual_Pronouns__c.fieldApiName] = this.referral.Individual_Pronouns__c
        fields[Physical_Address_Line_1__c.fieldApiName] = this.referral.Physical_Address_Line_1__c
        fields[Physical_Address_Postal_Code__c.fieldApiName] = this.referral.Physical_Address_Postal_Code__c
        fields[Physical_Address_Province__c.fieldApiName] = this.referral.Physical_Address_Province__c
        fields[Physical_Address_City__c.fieldApiName] = this.referral.Physical_Address_City__c
        fields[Individual_Home_Phone_Number__c.fieldApiName] = this.referral.Individual_Home_Phone_Number__c
        fields[Individual_Cell_Phone_Number__c.fieldApiName] = this.referral.Individual_Cell_Phone_Number__c
        fields[Referral_Notes__c.fieldApiName] = this.referral.Referral_Notes__c
        if (referralFor) fields[ICY_Referral_For__c.fieldApiName] = referralFor;
        fields[Status__c.fieldApiName] = 'Referral'
        fields[ICY_Referred_By__c.fieldApiName] = this.referral.ICY_Referred_By__c
        fields[ICY_Personal_Health_Number__c.fieldApiName] = this.ICY_Personal_Health_Number
        fields[ICY_Preferred_Method_of_Contact__c.fieldApiName] = this.referral.ICY_Preferred_Method_of_Contact__c
        fields[ICY_Other_Phone__c.fieldApiName] = this.referral.ICY_Other_Phone__c
        fields[ICY_If_Parent_Guardian_is_aware__c.fieldApiName] = this.referral.ICY_If_Parent_Guardian_is_aware__c
        fields[ICY_Reason_for_Referral__c.fieldApiName] = this.referral.ICY_Reason_for_Referral__c
        fields[ICY_Relevant_Information__c.fieldApiName] = this.referral.ICY_Relevant_Information__c
        fields[ICY_Current_Supports__c.fieldApiName] = this.referral.ICY_Current_Supports__c
        fields[ICY_Ethnicity__c.fieldApiName] = this.referral.ICY_Ethnicity__c
        fields[ICY_Preferred_Language__c.fieldApiName] = this.referral.ICY_Preferred_Language__c
        fields[ICY_Diagnosis__c.fieldApiName] = this.referral.ICY_Diagnosis__c
        fields[ICY_Medication__c.fieldApiName] = this.referral.ICY_Medication__c
        fields[ICY_Geographic_Area__c.fieldApiName] = this.referral.ICY_Geographic_Area__c
        if (medReferralReason) fields[ICY_Medical_Referral_Reason__c.fieldApiName] = medReferralReason;
        fields[Reason_for_Referral_if_Other__c.fieldApiName] = this.referral.Reason_for_Referral_if_Other__c
        fields[ICY_Can_We_Leave_a_Message_On_Cell__c.fieldApiName] = this.referral.ICY_Can_We_Leave_a_Message_On_Cell__c
        fields[ICY_Can_We_Leave_a_Message_On_Home_Phone__c.fieldApiName] = this.referral.ICY_Can_We_Leave_a_Message_On_Home_Phone__c
        fields[ICY_Leave_a_Message_On_other_Phone__c.fieldApiName] = this.referral.ICY_Leave_a_Message_On_other_Phone__c
        fields[ICY_Referral_Source__c.fieldApiName] = this.referral.ICY_Referral_Source__c;
        fields[ICY_Priority__c.fieldApiName] = this.referral.ICY_Priority__c;
        fields[ICY_CYMH__c.fieldApiName] = this.referral.ICY_CYMH__c;
        fields[ICY_Indigenous__c.fieldApiName] = this.referral.ICY_Indigenous__c;
        fields[ICY_CHILD_YOUTH_Aware__c.fieldApiName] = this.referral.ICY_CHILD_YOUTH_Aware__c;
        fields[ICY_Unknown_Address__c.fieldApiName] = this.referral.ICY_Unknown_Address__c;
        fields[ICY_Referral_Source_Description__c.fieldApiName] = this.referral.ICY_Referral_Source_Description__c;
        fields[ICY_Date_of_Referral__c.fieldApiName] = this.referral.ICY_Date_of_Referral__c;
        fields[OWNERID.fieldApiName] = this.referral.OwnerId;
        fields[Preferred_Contact_s_Name_Cell__c.fieldApiName] = this.referral.Preferred_Contact_s_Name_Cell__c;
        fields[Preferred_Contact_s_Name_Home__c.fieldApiName] = this.referral.Preferred_Contact_s_Name_Home__c;
        fields[Preferred_Contact_s_Name_Other__c.fieldApiName] = this.referral.Preferred_Contact_s_Name_Other__c;
        fields[Relationship_to_Individual_Cell__c.fieldApiName] = this.referral.Relationship_to_Individual_Cell__c;
        fields[Relationship_to_Individual_Home__c.fieldApiName] = this.referral.Relationship_to_Individual_Home__c;
        fields[Relationship_to_Individual_Other__c.fieldApiName] = this.referral.Relationship_to_Individual_Other__c;
        fields[Other_Relationship_Cell__c.fieldApiName] = this.referral.Other_Relationship_Cell__c;
        fields[Other_Relationship_Home__c.fieldApiName] = this.referral.Other_Relationship_Home__c;
        fields[Other_Relationship_Other__c.fieldApiName] = this.referral.Other_Relationship_Other__c;

        if (this.referralType == 'Professional Referral') fields[RecordTypeId.fieldApiName] = this.medicalRecordTypeId;
        else fields[RecordTypeId.fieldApiName] = this.generalRecordTypeId;

        let objectRecordInput = { 'apiName': 'Referral__c', fields };
        createRecord(objectRecordInput).then(response => {
            this.showSpinner = false;
            console.log('$$ Referral Record Created Successfully Response: ', response);
            console.log('$$ Request id: ' + response.id);
            this.referralRecordId = response.id;
            if (this.primaryContact.Contact_Person_First_Name__c && this.primaryContact.Contact_Person_Last_Name__c) {
                this.showSpinner = true;
                return createPrimaryContact({ caseContact: this.primaryContact, referralId: this.referralRecordId });
            } else {
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: this.referralRecordId,
                        actionName: 'view'
                    }
                });
            };
        }).then(result => {
            this.showSpinner = false;
            if (result) {
                console.log('$$ Primary Contact Created: ', result);
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: this.referralRecordId,
                        actionName: 'view'
                    }
                });
            }
        }).catch(error => {
            this.showSpinner = false;
            console.error('$$ Error Creating Referral Record: ', error);
            if (JSON.stringify(error).includes('ICY Referral Owner Email Flow')) {
                this.showToast(
                    'Error',
                     ICY_NoProgramLeader,
                    'error'
                )

            }

        });
    }

    showToast(title, message, variant) {
        window.scrollTo({ top: 0, behaviour: "smooth" });
        const evnt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'sticky'
        });

        this.dispatchEvent(evnt);
    }

    //Handle Previous Navigation
    handlePrevious() {
        if (this.page2) {
            this.page2 = false
            this.page1 = true
            this.page3 = false
            this.page4 = false;
        } else if (this.page3) {
            this.page2 = true;
            this.page3 = false;
            this.page1 = false;
            this.page4 = false;
        } else if (this.page4) {

            if (this.isYouthReferral) {
                this.page2 = false;
                this.page3 = true;
                this.page1 = false;
                this.page4 = false;
            }
            else {
                this.page2 = true;
                this.page3 = false;
                this.page1 = false;
                this.page4 = false;
            }
        }
    }


    //start Referral Flow
    startInterview() {
        this.page1 = false;
        this.page2 = true;
    }


    handleChange(event) {
        let n = event.target.name;
        if (n) {
            switch (n) {
                case 'First_Name__c':
                    this.referral.Individual_First_Name__c = event.target.value;
                    break;
                case 'Last_Name__c':
                    this.referral.Individual_Last_Name__c = event.target.value;
                    break;
                case 'ref-type':
                    this.referralType = event.target.value;
                    break;
                case 'Referral_For__c':
                    this.referral.ICY_Referral_For__c = event.target.value;
                    this.isYouthReferral = event.target.value.includes('Youth');
                    break;
                case 'Date_of_Birth__c':
                    this.referral.Individual_Date_of_Birth__c = event.target.value;
                    let agedif = Date.now() - new Date(this.referral.Individual_Date_of_Birth__c).getTime();
                    let ageDate = new Date(agedif);
                    this.referralAge = Math.abs(ageDate.getUTCFullYear() - 1970);
                    break;
                case 'Personal_Health_Number__c':
                    //this.referral.ICY_Personal_Health_Number__c = this.formatPHN(event.target.value);
                    //if(event.target.value.length==10){
                        var phnNumber = parseInt(event.target.value.replace(/[^0-9.]/g, ""));
                        console.log('@@phnNumber',phnNumber);
                        console.log('@@phnNumber length',String(phnNumber).length);
                        if(String(phnNumber).length==10){
                            //this.showSpinner = true;
                            this.ICY_Personal_Health_Number= String(phnNumber);
                            /*this.referral.ICY_Personal_Health_Number__c = this.formatPHN(phnNumber);
                            console.log(this.formatPHN(event.target.value));
                            checkIfHealthNumberIsUnique({ phn: event.target.value }).then(result => {
                                this.showSpinner = false;
                                if (!result) {
                                    let phnValue = event.target.value + '-1';
                                    this.referral.ICY_Personal_Health_Number__c = this.formatPHN(phnValue);
                                }
                            }).catch(error => {
                                this.showSpinner = false;
                                console.error('$$ Error validating PHN: ', error);
                            })*/
                        }
                   // }

                    break;
                case 'Preferred_Pronouns__c':
                    this.referral.Individual_Pronouns__c = event.target.value;
                    break;
                case 'Gender__c':
                    this.referral.Individual_Gender__c = event.target.value;
                    break;
                case 'Address__c':
                    this.referral.Physical_Address_Line_1__c = event.target.value;
                    break;
                case 'Address_Town__c':
                    this.referral.Physical_Address_City__c = event.target.value;
                    break;
                case 'Address_Postal_Code__c':
                    var s = ("" + event.target.value).replace(/\s/g, '');
                    var m = s.match(/^[ABCEGHJKLMNPRSTVXY]\d[ABCEGHJKLMNPRSTVXY][ -]?\d[ABCEGHJKLMNPRSTVXY]\d$/i); 

                    if (m == null) return;
                    var formattedCode = (m.input.substring(0, 3) + ' ' + m.input.substring(3, 6)).toUpperCase();
                    this.referral.Physical_Address_Postal_Code__c = formattedCode;
                    break;
                case 'Preferred_Method_of_Contact__c':
                    this.referral.ICY_Preferred_Method_of_Contact__c = event.target.value;
                    break;
                case 'Cell_Phone__c':
                    this.referral.Individual_Cell_Phone_Number__c = this.formatPhone(event.target.value);
                    break;
                case 'Home_Phone__c':
                    this.referral.Individual_Home_Phone_Number__c = this.formatPhone(event.target.value);
                    break;
                case 'Other_Phone__c':
                    this.referral.ICY_Other_Phone__c = this.formatPhone(event.target.value);
                    break;
                case 'ICY_If_Parent_Guardian_is_aware__c':
                    this.referral.ICY_If_Parent_Guardian_is_aware__c = event.target.value;
                    if (event.target.value == 'Yes') this.showPrimaryContact = true;
                    else this.showPrimaryContact = false;
                    break;
                case 'g-fn':
                    this.primaryContact.Contact_Person_First_Name__c = event.target.value;
                    break;
                case 'g-ln':
                    this.primaryContact.Contact_Person_Last_Name__c = event.target.value;
                    break;
                case 'g-rel':
                    this.primaryContact.Relationship_Subtype__c = event.target.value;
                    break;
                case 'g-type':
                    this.primaryContact.Contact_Type__c = event.target.value;
                    break;
                case 'g-sub-type':
                    this.primaryContact.Contact_Subtype__c = event.target.value;
                    break;
                case 'Con_Phone__c':
                    this.primaryContact.Contact_Person_Home_Phone_Number__c = this.formatPhone(event.target.value);
                    break;
                case 'g-wph':
                    this.primaryContact.Other_Relationship__c = event.target.value;
                    break;
                case 'Email__c':
                    this.primaryContact.Contact_Person_Email_Address__c = event.target.value;
                    break;
                case 'Reason_for_Referral__c':
                    this.referral.ICY_Reason_for_Referral__c = event.target.value;
                    break;
                case 'Relevant_Information__c':
                    this.referral.ICY_Relevant_Information__c = event.target.value;
                    break;
                case 'Current_Supports__c':
                    this.referral.ICY_Current_Supports__c = event.target.value;
                    break;
                case 'Ethnicity__c':
                    this.referral.ICY_Ethnicity__c = event.target.value;
                    break;
                case 'Preferred_Language__c':
                    this.referral.ICY_Preferred_Language__c = event.target.value;
                    break;
                case 'Diagnosis__c':
                    this.referral.ICY_Diagnosis__c = event.target.value;
                    break;
                case 'Medication__c':
                    this.referral.ICY_Medication__c = event.target.value;
                    break;
                case 'Additional_Comments__c':
                    this.referral.Referral_Notes__c = event.target.value;
                    break;
                case 'ICY_Geographic_Area__c':
                    this.referral.ICY_Geographic_Area__c = event.target.value;
                    this.showSpinner = true;
                    getICYQueueId({ geographicArea: event.target.value }).then(result => {
                        this.showSpinner = false;
                        if (result) this.referral.OwnerId = result;
                    }).catch(error => {
                        this.showSpinner = false;
                        console.error('$$ Error getting group owner: ' + error);
                    })
                    break;
                case 'Referral_Medical_Reason':
                    this.referral.ICY_Medical_Referral_Reason__c = event.target.value;                   
                    this.isFieldReasonForReferralifOtherRequired= false;
                    if (event.target.value.includes('Other'))
                        this.isFieldReasonForReferralifOtherRequired= true;
                    break;
                case 'Reason_for_Referral_if_Other__c':
                    this.referral.Reason_for_Referral_if_Other__c = event.target.value;
                    break;
                case 'Individual_Preferred_Name__c':
                    this.referral.Individual_Preferred_Name__c = event.target.value;
                    break;
                case 'ICY_Leave_a_Message_On_other_Phone__c':
                    this.referral.ICY_Leave_a_Message_On_other_Phone__c = event.target.checked;
                    break;
                case 'ICY_Can_We_Leave_a_Message_On_Home_Phone__c':
                    this.referral.ICY_Can_We_Leave_a_Message_On_Home_Phone__c = event.target.checked;
                    break;
                case 'ICY_Can_We_Leave_a_Message_On_Cell__c':
                    this.referral.ICY_Can_We_Leave_a_Message_On_Cell__c = event.target.checked;
                    break;
                case 'Preferred_Contact_s_Name_Cell__c':
                    this.referral.Preferred_Contact_s_Name_Cell__c = event.target.value;
                    break;
                case 'Preferred_Contact_s_Name_Home__c':
                    this.referral.Preferred_Contact_s_Name_Home__c = event.target.value;
                    break;
                case 'Preferred_Contact_s_Name_Other__c':
                    this.referral.Preferred_Contact_s_Name_Other__c = event.target.value;
                    break; 
                case 'Relationship_to_Individual_Cell__c':
                    this.referral.Relationship_to_Individual_Cell__c = event.target.value;
                    this.isFieldOtherCellRequired= false;
                    if (this.referral.Relationship_to_Individual_Cell__c=='Other')
                        this.isFieldOtherCellRequired= true;
                    break;
                case 'Relationship_to_Individual_Home__c':
                    this.referral.Relationship_to_Individual_Home__c = event.target.value;
                    this.isFieldOtherHomeRequired= false;
                    if (this.referral.Relationship_to_Individual_Home__c=='Other')
                        this.isFieldOtherHomeRequired= true;
                    break;
                case 'Relationship_to_Individual_Other__c':
                    this.referral.Relationship_to_Individual_Other__c = event.target.value;
                    this.isFieldOtherRequired= false;
                    if (this.referral.Relationship_to_Individual_Other__c=='Other')
                        this.isFieldOtherRequired= true;
                    break;  
                case 'Other_Relationship_Cell__c':
                    this.referral.Other_Relationship_Cell__c = event.target.value;
                    break;
                case 'Other_Relationship_Home__c':
                    this.referral.Other_Relationship_Home__c = event.target.value;
                    break;
                case 'Other_Relationship_Other__c':
                    this.referral.Other_Relationship_Other__c = event.target.value;
                    break;
                case 'Individual_Middle_Name__c':
                    this.referral.Individual_Middle_Name__c = event.target.value;
                    break;
                case 'ICY_Referred_By__c':
                    this.referral.ICY_Referred_By__c = event.target.value;
                    break;
                case 'ICY_CYMH__c':
                    this.referral.ICY_CYMH__c = event.target.value;
                    break;
                case 'ICY_Priority__c':
                    this.referral.ICY_Priority__c = event.target.value;
                    break;
                case 'ICY_Referral_Source__c':
                    this.referral.ICY_Referral_Source__c = event.target.value;
                    break;
                case 'ICY_Indigenous__c':
                    this.referral.ICY_Indigenous__c = event.target.value;
                    break;
                case 'ICY_CHILD_YOUTH_Aware__c':
                    this.referral.ICY_CHILD_YOUTH_Aware__c = event.target.checked;
                    break;
                case 'ICY_Unknown_Address__c':
                    this.referral.ICY_Unknown_Address__c = event.target.checked;
                    break;
                case 'ICY_Referral_Source_Description__c':
                    this.referral.ICY_Referral_Source_Description__c = event.target.value;
                    break;
                case 'ICY_Date_of_Referral__c':
                    this.referral.ICY_Date_of_Referral__c = event.target.value;
                    break;
            }
        }
    }


    //format phone number
    formatPhone(ph) {
        let s = ("" + ph).replace(/\D/g, '');
        let m = s.match(/^(\d{3})(\d{3})(\d{4})$/);
        if ((!m || m != null) && s.length < 10) {
            return ph;
        }
        let formattedPhone = (!m) ? null : "(" + m[1] + ") " + m[2] + "-" + m[3];
        return formattedPhone;
    }

    //format phone number
    formatPHN(phn) {
        let s = ("" + phn).replace(/\D/g, '');
        let m = s.match(/^(\d{4})(\d{3})(\d{3})$/);
        if ((!m || m != null) && s.length < 10) {
            return phn;
        }
        let formattedPHN = (!m) ? null : m[1] + "-" + m[2] + "-" + m[3];
        return formattedPHN;
    }

    formatPHNOnBlur(){
        if(this.ICY_Personal_Health_Number){
            let phn = this.ICY_Personal_Health_Number;
            let s = ("" + phn).replace(/\D/g, '');
            let m = s.match(/^(\d{4})(\d{3})(\d{3})$/);
            if ((!m || m != null) && s.length < 10) {
                this.referral.ICY_Personal_Health_Number__c= phn;
            }
            this.referral.ICY_Personal_Health_Number__c = (!m) ? null : m[1] + "-" + m[2] + "-" + m[3];
        }
    }
    populateOnlyNumbers(){
        if(this.ICY_Personal_Health_Number)
        this.referral.ICY_Personal_Health_Number__c = this.ICY_Personal_Health_Number;
    }

    //validate Postal Code
    validatePostalCode(event) {
        let postalCode = event.target.value;
        if (postalCode) {
          let t = event.target.name;
          var m = postalCode.match(/^[ABCEGHJKLMNPRSTVXY]\d[ABCEGHJKLMNPRSTVXY][ -]?\d[ABCEGHJKLMNPRSTVXY]\d$/i);  
          if (m == null) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Invalid Postal Code',
                        message: ICY_PleaseEnterPostalCode ,
                        variant: 'error'
                    }),
                );
                this.referral.Address_Postal_Code__c = null;
            }
        }
    }

    //Handle Lookup Referral Field
    handleLookup(event) {
        if (event.detail.selectedRecord) {
            this.referral.ICY_Referred_By__c = event.detail.selectedRecord.Id;
            this.referredByName = event.detail.selectedRecord.Contact_Person_First_Name__c + ' ' + event.detail.selectedRecord.Contact_Person_Last_Name__c;
        } else {
            this.referral.ICY_Referred_By__c = null;
            this.referredByName = null;
        }
    }

    //Create Contact
    createContact() {
        this.openModal = true;
    }

    //addReferral COntact
    addReferralContact() {
        this.showContactModal = true;
    }

    closeModal(event) {
        if (event.detail) this.referral.ICY_Referred_By__c = event.detail;
        this.showContactModal = false;
    }

}