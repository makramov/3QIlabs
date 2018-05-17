Feature: This feature file tests all the scenarios from week3FunctionalFlow tab on fatfreecrm.xlsx

  Background:
    * I read the data from the "fatfreecrm.xlsx" and "week3FunctionalFlow" tab
 
 @#1
 Scenario::Create and vefiry with getTask:: tasks.json,
    * execute "s_01"

 @#2
 Scenario::verify created task, capture date from headers:: tasks/"ID".json,
    * execute "s_02"

 @#3
 Scenario::update all values, insert the date captured from headers into the name:: tasks/"ID".json,
    * execute "s_03"

 @#4
 Scenario::verify values updated:: tasks/"ID".json,
    * execute "s_04"

 @#5
 Scenario::delete task:: tasks/"ID".json,
    * execute "s_05"

 @#6
 Scenario::verify deleted task:: tasks/"ID".json,
    * execute "s_06"
