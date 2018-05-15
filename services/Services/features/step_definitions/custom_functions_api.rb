#Use this file to define functions that can be called using setup steps and after steps columns in the excel as well as generate_request function. Also yo can modify generate request function as needed.
#You should only use other service calls in the functions you define.
#Example usage:


#use this function to write any code that you want to run before test suit
def custom_before_suit
  execute_test("send_get_1")
end

#custom function that can be ran before the scenario starts
def custom_before_scenario

end

# use this method to define any specific code for parsing a response.
# it has to return a hash of parsed json to be use as actual json response
def prase_custom_response(response_json)
  JSON.parse(response_json)
end

#Generate params for the request. Params should be saved to global $test_params hash and will get automatically replaced in the request/headers/expected response
def generate_request(req_param, test_params)
  if req_param.include? '"NEW_FIRSTNAME"'
    result = rand_string_alpha(5)
    test_params["NEW_FIRSTNAME"] = result
    test_params["FIRSTNAME"] = test_params["NEW_FIRSTNAME"]
  end
  if req_param.include? '"NEW_LASTNAME"'
    result = rand_string_alpha(5)
    test_params["NEW_LASTNAME"] = result
    test_params["LASTNAME"] = test_params["NEW_LASTNAME"]
  end
  if req_param.include? '"NEW_PASSWORD"'
    result = rand_string_alpha(8)
    $test_params["NEW_PASSWORD"] = result
    $test_params["PASSWORD"] = $test_params["NEW_PASSWORD"]
  end
  if req_param.include? '"NEW_USERNAME"'
    result = rand_string_alpha(15)
    $test_params["NEW_USERNAME"] = result
    $test_params["OLD_USERNAME"] = $test_params["USERNAME"] || $test_params["NEW_USERNAME"]
    $test_params["USERNAME"] = $test_params["NEW_USERNAME"]
  end
  if req_param.include? '"NEW_NAME"'
    result = rand_string_alpha(10)
    $test_params['NEW_NAME'] = result
    $test_params['OLD_NAME'] = $test_params['NAME'] || $test_params['NEW_NAME']
    $test_params['NAME'] = $test_params['NEW_NAME']
  end

  if req_param.include? '"NEW_EMAIL"'
    result = rand_string_alpha(10)
    $test_params["NEW_EMAIL"] = result + "@example.com"
    $test_params["EMAIL"] = $test_params["NEW_EMAIL"]
  end

  if req_param.include? '"NEW_PHONE"'
    rand_string_numeric(10)
    $test_params["NEW_PHONE"] = "(#{rand_string_numeric(3)})-#{rand_string_numeric(3)}-#{rand_string_numeric(4)}"
    $test_params["PHONE"] = $test_params["NEW_PHONE"]
  end

  if req_param.include? '"SOME_DATE_EXAMPLE"'
    suffix_string = "10:00 AM"
    prefix_string = Time.now.strftime("%m/%d/%y ")
    date_string = prefix_string + suffix_string
    $test_params['SOME_DATE_EXAMPLE'] = date_string
  end


end

#Function generates a random string
#param length of the string
#return random Alpha string
def rand_string_alpha(length, save_as = nil)
    chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNOPQRSTUVWXYZ'
    result = Array.new(length) { chars[rand(chars.length)].chr }.join
    current_test.test_params[save_as] = result if save_as
    result
end

def rand_alpha_numeric(length, save_as = nil)
  chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNOPQRSTUVWXYZ0123456789'
  result = Array.new(length) { chars[rand(chars.length)].chr }.join
  $test_params[save_as] = result if save_as
  result
end

def rand_string_numeric(length, save_as = nil)
  chars = '0123456789'
  result = Array.new(length) { chars[rand(chars.length)].chr }.join
  $test_params[save_as] = result if save_as
  result
end

def copy_param(existing, new)
  $test_params[new] = $test_params[existing]
end

def capture_int(key)
  $test_params[key] = @act_resp.to_i
end

#Available validations rules

#	ANYTHING  						will pass if value is anything other than null or completely missing
# INTEGER_POSITIVE 			must be a type of integer
# STRING_NUMERIC        must be a string and must be numeric positive/negative
# STRING_NUMERIC_POSITIVE must be a String, Numeric only and positive

def validate_special_value(v,v2)
  result = false
  case v
    when "ANYTHING"
      result = !v2.nil?
    when "NOTHING"
      result = v2.nil?
    when "STRING"
      result =v2 && v2.is_a?(String)
    when "STRING_OR_NULL"
      result =v2.nil? || (v2 && v2.is_a?(String))
    when "INTEGER"
      result = v2 && v2.is_a?(Integer)
    when"INTEGER_POSITIVE"
      result = v2 && v2.is_a?(Integer) && v2 > 0
    when "STRING_NUMERIC"
      result =v2 && v2.is_a?(String) && v2 =~ /\A\-?\d+\z/
    when "STRING_NUMERIC_POSITIVE"
      result = v2 && v2.is_a?(String) && v2 =~ /\A\d+\z/ && v2.to_i > 0
    when "CURRENT_UTC"
      result = v2 && (Time.now).getutc.strftime("%m/%d/%y %I:%M %p") == v2 || (Time.now - 59).getutc.strftime("%m/%d/%y %I:%M %p") == v2
      puts "CURRENT_UTC: " + (Time.now).getutc.strftime("%m/%d/%y %I:%M %p")
    when "DATE_TIME"
      check = DateTime.strptime(v2, '%m/%d/%y %I:%M %p').strftime("%m/%d/%y %I:%M %p") rescue false
      result = v2 == check if check
      puts "#{v2} != #{check}" unless result
    # when "DATE_TIME_Y_l"
    #   check = DateTime.strptime(v2, '%m/%d/%Y %l:%M %p').strftime("%m/%d/%Y %-l:%M %p") rescue false
    #   result = v2 == check if check
    #   puts "#{v2} != #{check}" unless result
    # when "DATE_TIME_Y"
    #   check = DateTime.strptime(v2, '%m/%d/%Y %I:%M %p').strftime("%m/%d/%Y %I:%M %p") rescue false
    #   result = v2 == check if check
    #   puts "#{v2} != #{check}" unless resul
    # when "DT_FULL_YEAR_TIME_ZONE"
    #   check = DateTime.strptime(v2, '%m/%d/%Y %I:%M %p %Z').strftime("%m/%d/%Y %I:%M %p") rescue false
    #   result = v2[0..-5] == check if check
    #   puts "#{v2} != #{check}" unless result
    # when "DATE_TIME_OR_NULL"
    #   if v2 == nil
    #     result = true
    #   else
    #     check = DateTime.strptime(v2, '%m/%d/%y %I:%M %p').strftime("%m/%d/%y %I:%M %p") rescue false
    #     result = v2 == check if check
    #     puts "#{v2} != #{check}" unless result
    #   end
  end
  result
end


#This function can be used to provide data for performance test. Params will go into the test_params of each thread.
#thread number is given to genarate the params for each thread as needed.
# params be given as array of hashes. The length of the arrays = number of threads
def get_test_params_performance(params_array)
  params_array.each do |params|
    params['TEST_VALUE'] ||= rand(9999).to_s
  end
end