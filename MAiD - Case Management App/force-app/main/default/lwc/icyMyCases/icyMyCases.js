import { LightningElement, wire } from "lwc";
import getAssignedCaseList from "@salesforce/apex/ICY_AccessCaseController.getAssignedCaseList";

const columns = [
  {
    label: "Case Number",
    fieldName: "caseId",
    type: "url",
    sortable: true,
    typeAttributes: { label: { fieldName: "caseNumber", target: "_blank" } },
  },
  { label: "Individual Name", fieldName: "individualName" },
  { label: "Status ", fieldName: "caseStatus" },
  { label: "Location", fieldName: "Location" },
  {
    label: "Date Created",
    fieldName: "dateTimeOpened",
    sortable: true,
    type: "date",
  },
];

export default class IcyMyCases extends LightningElement {
    data;
    columns = columns;
    defaultSortDirection = "asc";
    sortDirection = "asc";
    sortedBy='caseNumber';

    connectedCallback() {
      this.init();
    }

    init() {
      getAssignedCaseList()
        .then((result) => {
          console.log("$$ My cases: ", result);
          if (result && result.length > 0) {
            result.forEach((element) => {
              element["caseId"] = "/" + element["caseId"];
            });
            this.data = [];
            this.data = result;
          }
        })
        .catch((error) => {
          console.error("$$ Error Retrieving My Cases. ", error);
        });
    }

    refresh() {
      this.init();
    }

    sortBy(field, reverse, primer) {
      const key = primer
        ? function (x) {
            return primer(x[field]);
          }
        : function (x) {
            return x[field];
          };

      return function (a, b) {
        a = key(a);
        b = key(b);
        return reverse * ((a > b) - (b > a));
      };
    }

    onHandleSort(event) {
      const { fieldName: sortedBy, sortDirection } = event.detail;
      const cloneData = [...this.data];

      cloneData.sort(this.sortBy(sortedBy, sortDirection === "asc" ? 1 : -1));
      this.data = cloneData;
      this.sortDirection = sortDirection;
      this.sortedBy = sortedBy;
    }
}