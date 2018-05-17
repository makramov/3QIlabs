Feature: This feature file tests all the scenarios from week3 tab on fatfreecrm.xlsx

  Background:
    * I read the data from the "fatfreecrm.xlsx" and "week3" tab
 
  Scenario::createAccount:: accounts.json,
    * execute "s_01"

  Scenario::getAccountByAccountID:: accounts/ACCOUNT_ID.json,
    * execute "s_02"

  Scenario::getAccounts:: accounts.json,
    * execute "s_03"

  Scenario::updateAccount:: accounts/ACCOUNT_ID.json,
    * execute "s_04"

  Scenario::deleteAccount:: accounts/ACCOUNT_ID.json,
    * execute "s_05"

  Scenario::createLead:: leads.json,
    * execute "s_06"

  Scenario::getLeadByLeadID:: leads/LEAD_ID.json,
    * execute "s_07"

  Scenario::getLeads:: leads.json,
    * execute "s_08"

  Scenario::updateLead:: leads/LEAD_ID.json,
    * execute "s_09"

  Scenario::deleteLeads:: leads/LEAD_ID.json,
    * execute "s_10"

  Scenario::createTask:: tasks.json,
    * execute "s_11"

  Scenario::getTaskByTask_ID:: tasks/TASK_ID.json,
    * execute "s_12"

  Scenario::getTasks:: tasks.json,
    * execute "S_13"

  Scenario::updateTask:: tasks/TASK_ID.json,
    * execute "S_14"

  Scenario::deleteTask:: tasks/TASK_ID.json,
    * execute "s_15"
