/******************************************************************************************
** ICM STADD Project
*******************************************************************************************
** Class Name: UpdateCommunityIndividualObject
** Description: To define the invocable method so that Community field is updated based on Postal Code
** Version: 1.0
** 
**-----------------------------------------------------------------------------------------
**Modification Log:
**----------------
**Developer                  Date          Version               Description
**-----------------------------------------------------------------------------------------
**Sanjoy                     11/05/2018                          Created
********************************************************************************************/
public class UpdateCommunityIndividualObject {

     @InvocableMethod(label='Update Community on Individual' description='Updates the Community Field depending on Physical Postal Code')
    public static void updateCommunityIndividual(List<String> individualToUpdate) {
        
        //Map<Id, Postal_Code__c> postalCodeMap= new Map <Id, Postal_Code__c>([Select Name, Community__c FROM Postal_Code__c]);
        //Map<String, String> compareChart= new Map <String, String>();
       //for(Id posId: postalCodeMap.keyset()) {
        //compareChart.put(postalCodeMap.get(posId).Name,postalCodeMap.get(posId).Community__c); 
//}
		Map< Id, Account> individualMap= new Map <Id, Account>([Select PersonOtherPostalCode, Community__c FROM Account where Id IN :individualToUpdate ]);
          for (String indID : individualMap.keySet()){
                 String posCode=(individualMap.get(indID).PersonOtherPostalCode).left(3)+(individualMap.get(indID).PersonOtherPostalCode).right(3);
                  List <Postal_Code__c> postalList=[Select Name, Six_Digits__c,Community__c FROM Postal_Code__c where Name=: posCode];
                  If(!postalList.isEmpty())
                  individualMap.get(indID).Community__c=postalList[0].Community__c;
                  else
                  individualMap.get(indID).Community__c='Unknown';  
}
        update individualMap.values();
}

}