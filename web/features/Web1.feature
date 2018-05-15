Feature:

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