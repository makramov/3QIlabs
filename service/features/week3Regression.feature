Feature: This feature file tests all the scenarios from week3Regression tab on fatfreecrm.xlsx

  Background:
    * I read the data from the "fatfreecrm.xlsx" and "week3Regression" tab
 
 @#1
 Scenario:name:Verify field accept 64 char max:: accounts.json,
    * execute "s_01"

 @#2
 Scenario:name:Verify with space:: accounts.json,
    * execute "s_02"

 @#3
 Scenario:name:Verify with array:: accounts.json,
    * execute "s_03"

 @#4
 Scenario:name:invalid type, empty string:: accounts.json,
    * execute "s_04"

 @#5
 Scenario:name:Select value in assigned to:: accounts.json,
    * execute "s_05"

 @#6
 Scenario:name:Verify field accept 65 char max:: accounts.json,
    * execute "s_06"
