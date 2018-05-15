require 'active_support/all'
require 'roo'
require 'spreadsheet'
require 'pry'
require 'digest'

require 'securerandom'
require 'rubygems'


$my_root = File.join(File.dirname(__FILE__),'/')
$my_root_assets = File.join(File.dirname(__FILE__),'/../tc_assets/')
$manifest_file = File.join(File.dirname(__FILE__), '..', 'manifest.json')
$env_constants_file = JSON.parse(File.open("#{$my_root_assets}env_constants.json").read) rescue nil
$env_constants_file ||= JSON.parse(File.open("#{$my_root}env_constants.json").read) rescue raise("could not parse or find env_constants.json")
$params = JSON.parse(File.open($manifest_file).read)['params'] #Have access to all params in manifest file
env = $params['variables'][$params['variables'].keys.first]['name'] rescue nil
env ||= $params['environment']['name'] rescue nil
$env = env
$env_params = $env_constants_file['env_params'][env] rescue nil
$env_params ||= {}
common_params = $env_constants_file['common_params'] rescue nil
common_params ||= {}
$env_params = common_params.deep_merge $env_params
$env_urls = $env_constants_file['env_urls'][env] rescue nil
$env_urls ||= {}
$proxy = $env_constants_file['proxy'] rescue nil
$proxy ||= {}
$proxy['url'] = $proxy[env] if $proxy[env]
$capture_params = $env_constants_file['capture_params'] rescue []
$capture_paths = $env_constants_file['capture_paths'] rescue {}
$request_timeout = $env_constants_file['request_timeout'] rescue nil

$test_params = {}
$test_items = []
$validation_keys = $env_constants_file['validation_keys']
$log_limit = $env_constants_file['log_limit'] || 10000
$trim_values_limit = $env_constants_file['trim_values_limit']
$verify_ssl = $env_constants_file['verify_ssl']
$performance_test_started = false
$excel_cell_limit =32001 # how many charachters excel can store in 1 cell
$tests = {}
$log_all_requests = true
#$http_tool = :http_client
$http_tool = :rest_client
#$http_tool = :open_uri
#$http_tool == :em_http_request
# $http_tool = :typhoeus
#$http_tool = :http
if $http_tool == :rest_client
	require 'rest-client'
elsif $http_tool == :http_client
	require 'uri'
	require 'net/http'
elsif $http_tool == :open_uri
	require 'open-uri'
elsif $http_tool == :em_http_request
	require 'em-http-request'
elsif $http_tool == :http
	require 'http'
elsif $http_tool == :typhoeus
	require 'typhoeus'
end



And(/^execute "([^"]*)"$/) do |test_id|
	if $params["variables"] && $params["variables"]["performance"] && $params["variables"]["performance"]["enabled"] == "true"
    run_performance_test($params["variables"]["performance"])
		set_current_test(nil)
  else
    set_current_test($test_suit.load_test(test_id))
		current_test.run_test
		$test_suit.add_to_log current_test.log
		print_logs(current_test.log)
		current_test.raise_errors
  end
end

Given(/^I read the data from the "([^"]*)" and "([^"]*)" tab$/) do |excel_file_name, sheet_name|
  $test_suit = load_test_suit(excel_file_name, sheet_name, $test_suit)
  $test_suit.set_params($env_params, $env_urls, $test_params ,$test_items, $log_limit, $proxy)
  if $custom_before_suit_run.nil?
    begin
		custom_before_suit || custom_background_function
    rescue => e
			puts "No custom_before_suit function or #{e.to_s}"
    end
		$custom_before_suit_run = true
  end
	begin
  	custom_before_scenario
  rescue => e
		puts "No custom_before_scenario function or #{e.to_s}"
  end
end



# returns info about the test by id
def get_test_by_id(test_id)
	test = ServiceTest.new(test_id, $test_suit, $env_params, $env_urls, $test_params ,$test_items, $log_limit, $proxy)
	test.load_test_data
	[test.request_type, test.url, test.request_headers, test.request_body, test.expected_body, test.expected_code]
end

#only make a service call from the test given the id and optionally a capture parameter.
# does not check the test result
#a few new ways to call this method
#call_api_by_id("test_id")
#call_api_by_id("test_id",true)
#call_api_by_id(true,"test_id")
def call_api_by_id(capture = false, test_id = false)
	unless test_id.is_a?(String)
		new_capture = test_id
		test_id = capture
		capture = new_capture
	end
	parent_test = current_test
	puts "calling #{test_id} with capture as #{capture}"
	test = ServiceTest.new(test_id,  $test_suit, $env_params, $env_urls, current_test.test_params ,current_test.test_items, $log_limit, $proxy)
	set_current_test(test)
	test.load_test_data
	test.merge_request
	test.set_expected_params
	test.prepare_request
	test.rest_service_call
	test.parse_json_responses if capture
	test.capture_response_params if capture
ensure
	set_current_test(parent_test)
	return test.log
end

#run a complete API test from excel by test id, assuming the step to load data from excel was called
def execute_test(test_id)
	parent_test = current_test
	test_params =  parent_test.test_params rescue  $test_params
	test_items = parent_test.test_items rescue $test_items
	test = $test_suit.load_test(test_id,test_params ,test_items )
	set_current_test(test)
	test.run_test
	test.raise_errors(true)
ensure
		set_current_test(parent_test)
		return test.log
end

#get current test object
def current_test
	$tests[Process.pid]
end

#sets the current test in gobal variable for the current thread
# to be able to get the test object later with current_test method
def set_current_test(test)
	$tests[Process.pid] = test
end



And(/^I check request [^"]* in scenario "([^"]*)" "([^"]*)"$/) do |row, test_id|
	if $params["variables"] && $params["variables"]["performance"] && $params["variables"]["performance"]["enabled"] == "true"
		run_performance_test($params["variables"]["performance"], true)
		set_current_test(nil)
	else
		$test_suit.merge_row_data(row.to_i)
		current_test = $test_suit.load_test(test_id)
		set_current_test(current_test)
		current_test.run_test
		$test_suit.add_to_log current_test.log
		print_logs(current_test.log)
		current_test.raise_errors
  end
end

AfterStep do |scenario|
	$test_suit.log_results(scenario, current_test) if current_test && $test_suit
	set_current_test(nil)
end

After do |scenario|
	$test_suit.log_results(scenario, current_test) if current_test && $test_suit
	set_current_test(nil)
end


at_exit do
	$test_suit.create_excel_report if $test_suit
end

#prints logs nicely in cucumber html report
def print_logs(logs)
	puts "<pre>\n#{logs}\n</pre>"
end

# function needed to work with awetest
def take_screenshot_from_listener(a)
	a
end
