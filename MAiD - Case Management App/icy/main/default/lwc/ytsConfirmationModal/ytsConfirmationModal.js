import { LightningElement, api } from 'lwc';

export default class YtsConfirmationModal extends LightningElement {
    @api modalConfirmationText
    @api cancelBtnLbl
    @api okBtnLbl
    @api modalHeaderText
    
    cancelConfirmation(){
        this.dispatchEvent(new CustomEvent('cancelconfirm'));
    }

    deleteConfirmation(){
        this.dispatchEvent(new CustomEvent('okconfirm'));
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