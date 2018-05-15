Feature: This feature file tests all the scenarios from day7 tab on fatfreecrm.xlsx

  Background:
    * I read the data from the "fatfreecrm.xlsx" and "day7" tab
 
  Scenario:::: leads.json,
    * execute "createLead"

  Scenario:::: leads/LEAD_ID.json,
    * execute "getLeadByLeadID"

  Scenario:::: leads.json,
    * execute "getLeads"

  Scenario:::: leads/LEAD_ID.json,
    * execute "updateLead"

  Scenario:::: leads/LEAD_ID.json,
    * execute "deleteLeadByLeadID"

  Scenario:::: accounts.json,
    * execute "createAccount"

  Scenario:::: accounts/ACCOUNT_ID.json,
    * execute "getAccountByAccountID"

  Scenario:::: accounts.json,
    * execute "getAccounts"

  Scenario:::: accounts/ACCOUNT_ID.json,
    * execute "updateAccount"

  Scenario:::: accounts/ACCOUNT_ID.json,
    * execute "deleteAccount"

  Scenario:::: tasks.json,
    * execute "createTask"

  Scenario:::: tasks/TASK_ID.json,
    * execute "getTaskByTaskID"

  Scenario:::: tasks.json,
    * execute "getTasks"

  Scenario:::: tasks/TASK_ID.json,
    * execute "updateTask"

  Scenario:::: tasks/TASK_ID.json,
    * execute "deleteTask"
