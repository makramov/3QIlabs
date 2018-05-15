Feature:

Scenario: User log in.

Given User is in login page
When User enters "admin" then username text field
And User enters "admin" then password text field      
And User clicks login button
And User clicks welcome admin dropdown
And User clicks Logout
Then User successfully logged out