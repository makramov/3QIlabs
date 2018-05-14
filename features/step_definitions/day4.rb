Given(/^User is in login page$/) do
  require 'watir-webdriver'
  @browser=Watir::Browser.new :chrome
  @browser.driver.manage.window.maximize
  @browser.goto 'http://opensource.demo.orangehrmlive.com/'

end

When(/^User enters "([^"]*)" then username text field$/) do |admin|  
@browser.text_field(:id,'txtUsername').set 'admin'
end

When(/^User enters "([^"]*)" then password text field$/) do |admin|
  @browser.text_field(:id,'txtPassword').set 'admin'
end

When(/^User clicks login button$/) do
 @browser.button(:id,'btnLogin').click
end

When(/^User clicks welcome admin dropdown$/) do
  @browser.element(:xpath, "//a[@id='welcome']").click
end


When(/^User clicks Logout$/) do
 @browser.element(:xpath, "//div[@id='welcome-menu']/ul/li[2]").click
end

When(/^User enters "(.*?)" in username text field$/) do |arg1|
 @browser.text_field(:id,'txtUsername').set ("#{arg1}")
end

When(/^User enters "(.*?)" in password text field$/) do |arg2|
@browser.text_field(:id,'txtPassword').set ("#{arg2}")
end

Then(/^User close the browser$/) do
@browser.quit
end

When(/^I enter the credentials$/)do
@browser.text_field(:id,'txtUsername').set 'admin'
@browser.text_field(:id,'txtPassword').set 'admin'
@browser.button(:id,'btnLogin').click

end

Then(/^I logged successfully$/)do
@browser.element(:id, 'welcome').exist?
@browser.quit

end

Then(/^User successfully logged out$/) do
  @browser.element(:xpath, "//h1[@id='logInPanelHeading']")
  @browser.quit
end
