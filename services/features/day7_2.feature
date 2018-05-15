Feature: This feature file tests all the scenarios from day7_2 tab on fatfreecrm.xlsx

  Background:
    * I read the data from the "fatfreecrm.xlsx" and "day7_2" tab
 
 @#01
 Scenario:name:Verify field accept 64 char max:: tasks.json,
    * execute "s_01"

 @#02
 Scenario:name:Verify with space:: tasks.json,
    * execute "s_02"

 @#03
 Scenario:name:Verify with array:: tasks.json,
    * execute "s_03"

 @#04
 Scenario:name:invalid type, empty string:: tasks.json,
    * execute "s_04"

 @#05
 Scenario:Assigned To:Select value in assigned to:: tasks.json,
    * execute "s_05"

 @#06
 Scenario:Category:Select follow-up:: tasks.json,
    * execute "s_06"

 @#07
 Scenario:Category:Select Trip:: tasks.json,
    * execute "s_07"

 @#08
 Scenario:name:Verify field accept 64 char max:: accounts.json,
    * execute "s_08"

 @#08
 Scenario:name:Verify with space:: accounts.json,
    * execute "s_09"

 @#10
 Scenario:name:Verify with array:: accounts.json,
    * execute "s_10"

 @#11
 Scenario:name:invalid type, empty string:: accounts.json,
    * execute "s_11"

 @#12
 Scenario:Category:Select competitor:: accounts.json,
    * execute "s_12"

 @#13
 Scenario:Category:Select reseller:: accounts.json,
    * execute "s_13"

 @#14
 Scenario:firstname,
lastname:Verify field accept 64 char max:: leads.json,
    * execute "s_14"

 @#15
 Scenario:firstname,
lastname:Verify with space:: leads.json,
    * execute "s_15"

 @#16
 Scenario:firstname,
lastname:Verify with array:: leads.json,
    * execute "s_16"

 @#17
 Scenario:firstname,
lastname:invalid type, empty string:: leads.json,
    * execute "s_17"
