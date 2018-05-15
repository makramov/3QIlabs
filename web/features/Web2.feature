Feature:

Scenario: Log In
Given User is in login page
When I enter the credentials
Then I logged successfully


Scenario Outline: User negative Log in cases.

Given User is in login page
When User enters <username> in username text field
And User enters <password> in password text field      
And User close the browser

Examples:
| username | password |
|  ""      | ""       |
|  ""      | "admin"  |
| "admin"  | ""       |
| "admi"   | "admin"  |
| "admin"  | "admi"   |


Scenario: User log in.

Given User is in login page
When User enters "admin" then username text field
And User enters "admin" then password text field      
And User clicks login button
And User clicks welcome admin dropdown
And User clicks Logout
Then User successfully logged out