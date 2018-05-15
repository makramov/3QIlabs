class ServiceTest

  attr_accessor :test_id, :test_element, :scenario, :comment, :url,
                :request_body, :expected_body, :request_headers,
                :expected_headers, :expected_code, :request_type,
                :actual_code, :actual_body, :actual_headers, :error,
                :response_time, :log, :test_params, :test_items, :after_steps, :set_up_steps,
                :validation_steps, :capture, :api_to_call, :use_proxy, :test_element,
                :test_result, :ignore_error, :execution_time, :bytesize, :request_size


  def initialize(test_id, test_data_obj, env_params, env_urls, test_params = {}, test_items = [], log_limit = 10000, proxy = {})
    @test_result = :Incomplete
    @test_suit = test_data_obj
    @proxy = proxy
    @log_limit = log_limit
    @test_id = test_id
    @env_params = env_params
    @env_urls = env_urls
    @test_params = test_params
    @test_items = test_items
    @log = ''

  end

  def load_test_data
    @test_data = @test_suit.data[@test_id]
    header_columns = @test_suit.header_columns
    # if the current request is missing, this must be the sample request. will get the sample request instead.
    unless @test_data
      @test_data = @test_suit.sample_requests_by_id[@test_id]
      header_columns = @test_suit.s_r_header_columns
    end
    unless @test_data
      raise("unable to find test #{@test_id}")
    end

    @merge_test_id = @test_data[header_columns.index("smoke test id")] rescue nil
    @after_steps = @test_data[header_columns.index("after steps")] rescue nil
    @validation_steps = @test_data[header_columns.index("validation steps")] rescue nil
    @set_up_steps = @test_data[header_columns.index("set up steps")] rescue nil
    @capture = @test_data[header_columns.index("capture")] rescue nil
    @ignore_error = @test_data[header_columns.index("ignore")] rescue nil
    @request_type = @test_data[header_columns.index("request type") || header_columns.index("method/verb")] rescue nil
    @api_to_call = @test_data[header_columns.index("api name") || header_columns.index("end point")] rescue nil
    @url = @test_data[header_columns.index("url")] rescue nil
    @use_proxy = @test_data[header_columns.index("proxy")] rescue nil
    @scenario = @test_data[header_columns.index("scenario")] rescue ''
    @comment = @test_data[header_columns.index("comment")] rescue nil
    @test_element = @test_data[header_columns.index("variable")|| header_columns.index("element")] rescue ''
    @request_body = @test_data[header_columns.index("request")]
    @expected_body = @test_data[header_columns.index("expected response") || header_columns.index("response")]
    @request_headers = @test_data[header_columns.index("headers") || header_columns.index("header params")] rescue nil
    @expected_headers = @test_data[header_columns.index("expected headers")] rescue nil
    @expected_code = @test_data[header_columns.index("code") || header_columns.index("response code")] rescue nil

    data_scenario = @test_params['SCENARIO'] || @test_params['scenario'] || @test_params['Scenario']
    @scenario = "#{data_scenario} - #{@scenario}" if data_scenario
    @log = "********* Test Started ***********" if $log_all_requests
    @actual_body = nil
    @actual_headers = nil
    @actual_code = nil
    @response_time = 0
    @error = ''
  end

  def set_expected_params
    @request_headers ||= '{}'
    @expected_code = @expected_code.to_i
    @empty_expected_header = !@expected_headers
    @empty_expected_response = !@expected_body
    @expected_body ||= ''
    @expected_headers ||= '{}'
    @use_proxy = @use_proxy =~ /[Yy]/
    @comment ||= ''
    @scenario = replace_params(@scenario, [@test_params, @test_items, @env_params])
  end

  def run_test
    test_start_time = Time.now
    load_test_data
    merge_request
    set_expected_params
    run_setup_steps
    prepare_request
    rest_service_call
    prepare_expected_response
    parse_json_responses
    capture_response_params
    validate_result
    run_validation_steps if no_errors
    run_after_steps if no_errors
    @log << "\n" + "*********** Test #{@test_result.to_s}.***********" if $log_all_requests
    @execution_time = ((Time.now - test_start_time)*1000).to_i
    @log = "Execution Time: #{@execution_time} ms\n" + @log if $log_all_requests
  end

  def print_log
    puts @log
  end

  def raise_errors(with_log = false)
    if @test_result == :Ignored
      @log << @comment if $log_all_requests
    elsif errors?
      fail @comment + "\n" + @log + "\n" + @error if with_log
      fail @comment + "\n" + @error
    else
      @log << "\n" + "*********** Test passed.***********" if $log_all_requests
    end
  end

  def no_errors
    @error == ''
  end

  def errors?
    !no_errors
  end

  def capture_response_params
    if !@capture.nil? && @capture.to_s.downcase =~ /^(ye?s?)$/
      capture_test_params @actual_json_response.deep_dup, @test_params if @actual_json_response.is_a? Hash
      capture_test_params @actual_headers.dup, @test_params
      @test_params['capturedResponse'] = @actual_body unless @actual_json_response.is_a? Hash
    elsif @capture && @capture.to_i == 0
      param_to_capture = nil
      param_to_capture = @capture unless @capture.downcase == 'p'
      capture_by_path(@actual_json_response, @test_params, param_to_capture) if @actual_json_response.is_a? Hash
      capture_by_path(@actual_headers, @test_params, param_to_capture)
      @test_params['capturedResponse'] = @actual_body unless @actual_json_response.is_a? Hash
    elsif !@capture.nil?
      item_index = @capture.to_i - 1
      @test_items ||= []
      @test_items[item_index] ||= {}
      capture_test_params @actual_json_response.deep_dup, @test_items[item_index] if @actual_json_response.is_a? Hash
      capture_test_params @actual_headers.dup, @test_items[item_index]
      capture_by_path(@actual_json_response, @test_items[item_index]) if @actual_json_response.is_a? Hash
      capture_by_path(@actual_headers, @test_items[item_index])
      @test_items[item_index]['capturedResponse'] = @actual_body unless @actual_json_response.is_a? Hash
    end
    if $log_all_requests
      @log << "\n" + "***Current Params****"
      @log << "\n" + prepare_json_to_log(@test_params).to_s.first(@log_limit)
      @log << "\n" + "***test items**"
      @log << "\n" + prepare_json_to_log(@test_items).to_s.first(@log_limit)
      @log << "\n" + "*********************"
    end
  end

  def validate_result
    result = ''
    @error << "Missing expected response, header, or code\n" if @empty_expected_header && @empty_expected_response && (!@expected_code || @expected_code == 0)
    @test_result = :Fail if errors?
    if no_errors
      result << validate_body
      result << validate_code
      result << validate_header
    end
    @error << result
    if errors? && @test_result != :Fail && @ignore_error
      @test_result = :Ignored
      @log << "\n" + "Errors ignored for Response/Headers/Code based on #{@comment}\n" if $log_all_requests
      @log << result if $log_all_requests
    elsif no_errors
      @test_result = :Pass
    else
      @test_result = :Fail
    end
  end

  #validate for  error, returns empty string or string with error with a newline
  def validate_code
    error = ''
    if !@expected_code.nil? && @expected_code != 0 && @expected_code != ''
      @log << "\n******* Expected Code: #{@expected_code}" if $log_all_requests
      if @actual_code != @expected_code
        error = "Response Code: [#{@expected_code}, #{@actual_code}]\n"
      end
    end
    error
  end

  # @parses expected and actual json responses to be ready to validate
  def parse_json_responses
    if is_array_in_string(@expected_body)
      resp_par = "{\"arrayResponse\":" + @expected_body + "}"
    else
      resp_par = @expected_body
    end
    resp_par = '{}' if resp_par == ''
    @expected_json_response = JSON.parse(resp_par) rescue resp_par
    begin
      if is_array_in_string(@actual_body)
        act_par = "{\"arrayResponse\":" + @actual_body + "}"
      else
        act_par = @actual_body
      end
      @actual_json_response = JSON.parse(act_par)
    rescue => e
      @actual_json_response = prase_custom_response(act_par) rescue nil
      if $log_all_requests
        if @actual_json_response
          @log << "\n*** Parsed response with custom function:\n"
          @log << prepare_json_to_log(@actual_json_response)
        else
          @log << "\n" + "** Response is not a json and did not parse with custom function"
          @log << "\n" + e.to_s
        end
        @log << "\n" + "************"
      end
    end
  end

  def is_array_in_string(string)
    string.is_a?(String) && string.strip[0] == '[' && string.strip[-1] == ']'
  end

  #validate for  error, returns empty string or string with error with a newline
  def validate_body
    error = nil
    if $log_all_requests && !@empty_expected_response
      @log << "\n************Expected Response: *****************\n"
    end
    if special_value(@expected_body)
      act_body = @actual_body
      act_body = nil if @actual_body == ''
      result = validate_special_value(@expected_body, act_body)
      @log << @expected_body if $log_all_requests
      error = "Body expected = #{@expected_body }, actual: #{@actual_body}" unless result
    else
      unless @empty_expected_response
        if @expected_json_response.is_a?(Hash) && @actual_json_response.is_a?(Hash)
          begin
            @log << prepare_json_to_log(@expected_json_response) if $log_all_requests
            error = different?(@expected_json_response.deep_dup, @actual_json_response.deep_dup)
          rescue => e
            error = e.to_s + e.backtrace.to_s
          end
          error = "Did not receive the expected response.. \nDifference is reported in format(Nesting=>[Expected_response, Actual_response]) \n#{prepare_json_to_log(error)}\n" if error
        else
          @log << @expected_body if $log_all_requests
          error = "Responses do not match: Different Types: expected: #{@expected_body} actual:#{@actual_body}\n" if @expected_body != @actual_body
        end
      end
    end
    unless @empty_expected_response
      @log << "\n*****************************" if $log_all_requests
    end
    error || ''
  end

  #validate for  error, returns empty string or string with error with a newline
  def validate_header
    exp_headers = JSON.parse(@expected_headers)
    unless exp_headers.empty?
      if $log_all_requests
        @log << "\n******* Expected Headers:**********\n"
        @log << prepare_json_to_log(@expected_headers)
        @log << "\n**************************"
      end
    end
    error = different?(exp_headers.dup, @actual_headers.dup)
    error = "Did not receive the expected headers.. \nDifference is reported in format(Nesting=>[Expected_header, Actual_header]) \n#{error}\n" if error
    error || ''
  end

  def run_validation_steps
    begin
      @validation_steps = replace_params(@validation_steps, [@test_params, @test_items, @env_params])
      @validation_steps = nil if @validation_steps == 'null'
      if !@validation_steps.nil? && @validation_steps.length > 1
        execute_steps(@validation_steps)
        @test_result = :Pass if @test_result != :Fail
      end
    rescue => e
      @error << e.to_s + "\n"
      if @test_result != :Fail && @ignore_error
        @log << "\n" + "Errors ignored for validation steps based on #{@comment}\n" if $log_all_requests
        @log << e.to_s + "\n" if $log_all_requests
        @test_result = :Ignored
      end
    end
  end

  def run_after_steps
    begin
      @after_steps = replace_params(@after_steps, [@test_params, @test_items, @env_params])
      @after_steps = nil if @after_steps == 'null'
      if !@after_steps.nil? && @after_steps.length > 1
        execute_steps(@after_steps)
      end
    rescue => e
      if $log_all_requests
        @log << "\n" + 'after steps error:'
        @log << "\n" + e.to_s
        @log << "\n" + '-----'
      end
    end
  end

  def prepare_expected_response
    @expected_body = replace_params(@expected_body, [@test_params, @test_items, @env_params])
    if @request_type == 'SOAP'
      @expected_body = xml_string_to_hash(@expected_body).to_json
    end
    @expected_headers = replace_params(@expected_headers, [@test_params, @test_items, @env_params])
  end

  def merge_request(merge_test_id = @merge_test_id)
    @request_headers ||= '{}'
    if merge_test_id
      @merge_test_data = @test_suit.sample_requests_by_id["#{merge_test_id}"]
      if !@merge_test_data
        if @test_suit.data[merge_test_id]
          merge_test = ServiceTest.new(merge_test_id, @test_suit, @env_params, @env_urls, @test_params, @test_items, @log_limit, @proxy)
          merge_test.load_test_data
          merge_test.merge_request
          merge_api_tests(merge_test)
        else
          raise "no such merge request found for id #{merge_test_id}"
        end
      else
        merge_with_sample
      end
    end
  end

  def merge_with_sample
    @merge_header_columns = @test_suit.s_r_header_columns if @merge_test_data
    @url ||= @merge_test_data[@merge_header_columns.index("url")] rescue nil
    @api_to_call ||= @merge_test_data[@merge_header_columns.index("api name") || @merge_header_columns.index("end point")] rescue nil
    @request_type ||= @merge_test_data[@merge_header_columns.index("request type") || @merge_header_columns.index("method/verb")] rescue nil
    @ignore_error ||= @merge_test_data[@merge_header_columns.index("ignore")] rescue nil
    @use_proxy ||= @merge_test_data[@merge_header_columns.index("proxy")] rescue nil
    @scenario ||= @merge_test_data[@merge_header_columns.index("scenario")] rescue nil
    @comment ||= @merge_test_data[@merge_header_columns.index("comment")] rescue nil
    if @merge_test_data
      sample_header = @merge_test_data[@merge_header_columns.index("headers") || @merge_header_columns.index("header params")] rescue nil
      sample_header ||= '{}'
      @request_headers = string_to_json_merge(@request_headers, sample_header)
      if @request_type == 'GET' || @request_type == 'DELETE'
        true #TODO nothing is in the request will it stay this way
      elsif @request_type.downcase == 'soap'
        sample_request = @merge_test_data[@merge_header_columns.index("request")]
        @request_body = replace_xml_node(sample_request, @request_body)
      else #POST etc..
        sample_request = @merge_test_data[@merge_header_columns.index("request")]
        @request_body = string_to_json_merge(@request_body, sample_request)
      end
    end
  end

  def merge_api_tests(merge_test)
    @after_steps ||= merge_test.after_steps
    @validation_steps ||= merge_test.validation_steps
    @set_up_steps ||= merge_test.set_up_steps
    @capture ||= merge_test.capture
    @ignore_error ||= merge_test.ignore_error
    @request_type ||= merge_test.request_type
    @api_to_call ||= merge_test.api_to_call
    @url ||= merge_test.url
    @use_proxy ||= merge_test.use_proxy
    @scenario ||= merge_test.scenario
    @comment ||= merge_test.comment
    @test_element ||= merge_test.test_element
    if @request_type.downcase == 'soap'
      @request_body = replace_xml_node(merge_test.request_body, @request_body)
    else
      @request_body = string_to_json_merge(@request_body, merge_test.request_body)
    end
    @expected_body ||= merge_test.expected_body
    @request_headers = string_to_json_merge(@request_headers, merge_test.request_headers)
    @expected_headers ||= merge_test.expected_headers
    @expected_code ||= merge_test.expected_code
  end

  def string_to_json_merge(primary, secondary)
    deep_merge_custom(JSON.parse(secondary), JSON.parse(primary)).to_json rescue (primary || secondary)
  end

  def run_setup_steps
    @set_up_steps = replace_params(@set_up_steps, [@test_params, @test_items, @env_params])
    @set_up_steps = nil if @set_up_steps == 'null'
    if !@set_up_steps.nil? && @set_up_steps.length > 1
      begin
        execute_steps(@set_up_steps)
      rescue => e
        @error << e.to_s + "\n"
        raise_errors(true)
      end
    end
  end

  def clear
    @test_params.clear
    @test_items.clear
  end

  def execute_steps(steps)
    steps = steps.split(', ')
    steps.each {|step|
      if $log_all_requests
        @log << "\n" + "* Executing function call **"
        @log << "\n" + "#{step}"
      end
      result = eval("#{step}")
      if $log_all_requests
        @log << "\n" + result if result.is_a?(String)
        @log << "\n" + "*********end**********"
      end
    }
  end


  def generate_values(string)
    begin
      generate_request(string, @test_params) if string
    rescue => e
      @error = "Error: #{e.to_s}\n #{e.backtrace.to_s}"
      @log << "/n" + @error if $log_all_requests
      raise_errors(true)
    end
  end

  def prepare_request
    @api_to_call ||= ''
    @url = (@env_urls[@url] || @url) if @url
    @url = @url + @api_to_call unless @request_type.downcase == 'soap'
    @request_type ||= 'POST'
    @request_type.upcase!

    generate_values(@request_headers)
    generate_values(@url)
    generate_values(@request_body)

    @request_headers = replace_params(@request_headers, [@test_params, @test_items, @env_params], true)
    if @request_type == 'GET' || @request_type == 'DELETE'
      @url = "#{@url}#{@request_body}"
      @request_body = ""
    elsif @request_body
      @request_body = replace_params(@request_body, [@test_params, @test_items, @env_params], true)
    end
    @url = replace_params(@url, [@test_params, @test_items, @env_params], true)
    @request_headers_hash = JSON.parse(@request_headers) rescue {}


    @url = URI.encode @url

  end

  # def force_json_request
  #   if @request_body.is_a?(String)
  #     JSON.parse(@request_body) rescue fail("request Json could not be parsed, need to fix json request: Make sure special characters are escaped properly\n #{@request_body}") if @request_body
  #   end
  # end
  def rest_service_call
    @actual_body = nil
    @actual_headers = nil
    @actual_code = nil
    @response_time = 0

    $request_timeout ||= 60
    beginning_time = nil
    end_time = nil
    if $http_tool == :rest_client
      RestClient.proxy = @proxy["url"] if @use_proxy && @proxy["url"]
    end
    #begin - rescue block for capturing error codes so the script does not stop.

    if @request_type == 'SOAP'
      require 'savon'
      request_body = nil

      begin
        @request_body_hash = JSON.parse(@request_body)
      rescue Exception => e
        request_body = 'xml'
        @request_body_xml = @request_body
      end
      beginning_time = Time.now
      begin
        client = get_soap_client(@url)
        if request_body == 'xml'
          resp = call_and_fail_gracefully(client, @api_to_call.to_sym, xml: @request_body)
        else
          resp = call_and_fail_gracefully(client, @api_to_call.to_sym, :message => @request_body_hash)
        end
        act_resp = resp.http.body
      rescue => e
        act_resp = resp
        @error = "Request failed: #{resp}"
      end
      end_time = Time.now
      act_resp_headers = resp.http.headers rescue {}
      @response_time = (end_time - beginning_time).to_s rescue 0
      @act_resp_headers_xml = generate_xml(act_resp_headers) rescue ''
      log_request if $log_all_requests
      @actual_headers = @act_resp_headers_xml
      @actual_code = resp.http.code rescue 0
      @actual_body = act_resp || ''
      log_response if $log_all_requests
      @request_body = xml_string_to_hash(@request_body).to_json rescue @request_body


      @actual_headers = act_resp_headers
      @actual_body = xml_string_to_hash(@actual_body).to_json rescue @actual_body


    else


      request_params = {}
      request_params[:url]= @url
      request_params[:timeout]= $request_timeout
      request_params[:open_timeout]= $request_timeout
      request_params[:verify_ssl]= $verify_ssl
      request_params[:headers]= @request_headers_hash
      request_params[:method]= @request_type.downcase.to_sym
      begin
        case request_params[:method]
          when :post_multipart #code to attach files to the multipart request
            @request_type = "POST"
            request_params[:method]= :post
            @request_body_hash = JSON.parse(@request_body) if @request_body rescue {}
            @request_body_hash[:multipart] = true
            @request_body_hash.each do |key, file|
              upload_file = File.new("#{$my_root_assets}#{file}", 'rb') rescue nil
              upload_file ||= File.new("#{$my_root}#{file}", 'rb') rescue file
              @request_body_hash[key] = upload_file
            end
            request_params[:payload]= @request_body_hash
            # request_params[:method]= :post
            # @request_body_hash = JSON.parse(@request_body) if @request_body rescue {}
            # @request_body_hash[:multipart] = true
            # new_request = []
            # @request_body_hash.each do |key, files|
            #   files = [files] if files.is_a? String
            #   next unless files.is_a?(Array)
            #   files.each {|file|
            #     upload_file = File.new("#{$my_root_assets}#{file}", 'rb') rescue nil
            #     upload_file ||= File.new("#{$my_root}#{file}", 'rb') rescue file
            #     new_request.push([key, upload_file])
            #   }
            # end
            # @request_body = new_request.to_json
            # @request_body_hash = new_request
            # request_params[:payload]= @request_body_hash
          when :get, :delete
          else
            if @request_headers_hash["Content-Type"] == "application/x-www-form-urlencoded"
              @request_body_hash = JSON.parse(@request_body) if @request_body rescue {}
              request_params[:payload]=@request_body_hash
            else
              request_params[:payload]= @request_body
            end
        end

        if $http_tool == :rest_client
          beginning_time = Time.now
          act_resp = RestClient::Request.execute(request_params)
        elsif $http_tool == :http_client
          url = URI(request_params[:url])
          http = Net::HTTP.new(url.host, url.port)
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE

          case request_params[:method]
            when :get
              request = Net::HTTP::Get.new(url)
            when :post
              request = Net::HTTP::Post.new(url)
            else
              fail('unimplemented request mehtod, please implement')
          end
          request_params[:headers].each_key do |key|
            request[key.downcase] = request_params[:headers][key]
          end
          request["connection"] = "keep-alive"
          request["User-Agent"] = "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36"
          #request["user-agent"] = "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36"
          if @request_headers_hash["Content-Type"] == "application/x-www-form-urlencoded"
            request_params[:payload] = URI.encode_www_form request_params[:payload]
          end
          request.body = request_params[:payload]
          beginning_time = Time.now
          act_resp = http.request(request)
        end
        if $http_tool == :typhoeus
          request = Typhoeus::Request.new(
              request_params[:url],
              method: request_params[:method],
              body: request_params[:payload],
              headers: request_params[:headers],
              ssl_verifypeer: false,
              timeout: request_params[:timeout],
          #cookiefile: "/cookiefile",
          #cookiejar: "cookiefile"
          )
          request.run
          act_resp = request.response
          if act_resp.timed_out?
            # aw hell no
            @error = "Request time out"
          elsif act_resp.code == 0
            @error = "Could not get an http response, something's wrong.\n #{response.return_message}"
          end

        end
        if $http_tool == :http
          url = request_params[:url]
          if @request_headers_hash["Content-Type"] == "application/x-www-form-urlencoded"
            to_post = :form
          else
            to_post = :body
          end

          beginning_time = Time.now
          case request_params[:method]
            when :get
              act_resp = HTTP.headers(request_params[:headers]).follow.get(url)
            when :post
              act_resp = HTTP.headers(request_params[:headers]).follow.post(url, to_post => request_params[:payload])
            else
              fail('unimplemented request mehtod, please implement')
          end
        end

        end_time = Time.now
      rescue ::NotImplementedError => e
        raise(e)
      rescue => e
        end_time = Time.now
        begin
          @actual_code = e.to_s[0..2].to_i
          @actual_body = e.response.body
          @actual_headers = e.response.raw_headers
        rescue => z
          @actual_body = ''
          @error = "Error: #{e.to_s}\n #{e.backtrace.to_s}"
        end
      ensure
        log_request if $log_all_requests
        if $http_tool == :rest_client
          RestClient.proxy = "" if @use_proxy && @proxy["url"]
          @actual_headers ||= act_resp.raw_headers rescue {}
          @actual_headers = Hash[@actual_headers.map {|k, v| [k, v[0]]}]
          @actual_code ||= act_resp.code rescue 0
          @actual_body ||= act_resp.to_s
        elsif $http_tool == :http_client
          @actual_headers = JSON.parse(act_resp.to_json) rescue {}
          @actual_headers = Hash[@actual_headers.map {|k, v| [k, v[0]]}]
          @actual_code ||= act_resp.code.to_i rescue 0
          @actual_body ||= act_resp.body
        elsif $http_tool == :http
          @actual_headers = act_resp.headers.to_h
          @actual_headers = @actual_headers.map {|k, v| [k.downcase, v]}.to_h
          @actual_code ||= act_resp.code rescue 0
          @actual_body ||= act_resp.body.to_s
        elsif $http_tool == :typhoeus
          @actual_headers = act_resp.headers
          @actual_code ||= act_resp.response_code rescue 0
          @actual_body ||= act_resp.response_body
          @request_size = act_resp.request_size rescue 0
        end
        @bytesize = @actual_body.bytesize + @actual_headers.to_json.bytesize rescue 0
        if $http_tool == :typhoeus
          @response_time = (act_resp.options[:total_time]*1000).to_i
        else
          @request_size = @url.bytesize + @request_body.bytesize + @request_headers.bytesize
          @response_time = ((end_time - beginning_time)*1000).to_i rescue 0
        end

        log_response if $log_all_requests
      end
    end
  end

  def log_response
    @log << "\n" + "************Response*************"
    @log << "\n" + "Status: #{@actual_code}"
    @log << "\n" + "Duration: #{@response_time} ms"
    #act_resp = act_resp.to_s.force_encoding('iso-8859-1').encode('utf-8')
    # need to reencode because it breaks html reports
    @log << "\n" + prepare_json_to_log(@actual_body.force_encoding('iso-8859-1').encode('utf-8')).to_s.first(@log_limit)
    @log << "\n" + "******Response Headers***********"
    @log << "\n" + prepare_json_to_log(@actual_headers).to_s.first(@log_limit)
    @log << "\n" + "*********************************"
  end

  def log_request
    @log << "\n" + "*********************************"
    @log << "\n" + "Request: #{@request_type}"
    @log << "\n" + "URL: " + @url
    @log << "\n" + "************Header***************"
    @request_headers_hash.each_key {|key|
      @log << "\n" + "#{key}:#{@request_headers_hash[key].to_s.first(@log_limit)}"
    }
    if @request_type != 'GET' && @request_type != 'DELETE'
      @log << "\n" + "************Request**************"
      @log << "\n" + "#{prepare_json_to_log(@request_body).to_s.first(@log_limit)}"
    end
    @log << "\n" + "*********************************"
  end

end

class APITestSuit

  attr_accessor :header_columns, :sample_requests_by_id, :s_r_header_columns, :excel_file_name, :sheet_name, :data, :log, :test_row_data

  def initialize(excel_file_name, sheet_name)

    @log = ''
    @excel_file_name = excel_file_name
    @sheet_name = sheet_name
    book = Roo::Spreadsheet.open("#{$my_root_assets}#{excel_file_name}") rescue nil
    book ||= Roo::Spreadsheet.open("#{$my_root}#{excel_file_name}")
    user_data = book.sheet("#{sheet_name}")
    @sample_requests_by_id = {}
    @data = {}
    for i in 1..user_data.last_row
      @data[user_data.row(i)[0].to_s] = user_data.row(i)[1..user_data.last_column]
    end
    @header_columns = user_data.row(1)[1..user_data.last_column]
    @header_columns.map! {|el| el.downcase rescue nil}
    book1 = Roo::Spreadsheet.open("#{$my_root_assets}sample_requests.xlsx") rescue nil
    book1 ||= Roo::Spreadsheet.open("#{$my_root}sample_requests.xlsx") rescue nil
    sample_requests = book1.sheet("sample_requests") rescue nil
    book1 ||= Roo::Spreadsheet.open("#{$my_root_assets}Smoke_test.xlsx") rescue nil
    book1 ||= Roo::Spreadsheet.open("#{$my_root}Smoke_test.xlsx") rescue nil
    sample_requests ||= book1.sheet("Smoke_test") rescue nil
    unless sample_requests
      sample_requests = book.sheet("sample_requests") rescue nil
      unless sample_requests
        sample_requests = book.sheet("Smoke_test") rescue nil
      end
    end
    #sample request will be found by unique key API NAME_Request Type
    #if there is no request type it will only use API Name
    if sample_requests
      for i in 1..sample_requests.last_row #have sample request by id, considering adding since we may have save requests path for differet actions
        @sample_requests_by_id[sample_requests.row(i)[0].to_s] = sample_requests.row(i)[1..sample_requests.last_column]
      end
      @s_r_header_columns = sample_requests.row(1)[1..sample_requests.last_column]
      @s_r_header_columns.map! {|el| el.downcase rescue nil}
    end

    @test_row_data ||= get_row_data(sheet_name) rescue nil

    @report_data = [["ID",
                     "Result",
                     "comment",
                     "Element",
                     "Scenario",
                     "Date/Time",
                     "Log",
                     "URL",
                     "Method",
                     "Headers",
                     "Payload",
                     "Expected Response",
                     "Actual Response",
                     "Expected Headers",
                     "Actual Headers",
                     "Time(s)",
                     "Exp Code",
                     "Act Code",
                     "Issue",
                     "Note"]]
    @report_data_awe_report = [["ID", "Element", "Scenario", "Result", "Date/Time", "URL", "Method", "Headers", "Payload", "Expected Response", "Actual Response", "Expected Headers", "Actual Headers", "Time(s)", "Exp Code", "Act Code", "Issue", "Note", "Log"]]
  end

  def get_row_data(sheet_name)
    book = Roo::Spreadsheet.open("#{$my_root_assets}data.xlsx") rescue nil
    book ||= Roo::Spreadsheet.open("#{$my_root}data.xlsx") rescue nil
    user_data = book.sheet("#{sheet_name}_#{$params['environment']['name']}")
    row_data = {}
    for i in 0...user_data.last_column
      row_data[user_data.row(1)[i]] = []
    end
    for i in 2..user_data.last_row
      count =0
      row_data.each_value do |value|
        value << user_data.row(i)[count]
        count += 1
      end
    end
    row_data.delete(nil)
    row_data
  end

  def merge_row_data(row, test_params = @test_params)
    @test_row_data.each_key do |key|
      value = @test_row_data[key][row-1]
      #allow to store json/arrays in excel and automatically parse those
      if value.is_a?(String) && can_parse_json(value)
        value = JSON.parse(value)
      end
      test_params[key] = value
    end
    test_params
  end

  def add_to_log(log)
    @log << log
  end


  def load_test(test_id, test_params = @test_params, test_items = @test_items)
    @current_test = ServiceTest.new(test_id, self, $env_params, $env_urls, test_params, test_items, $log_limit, $proxy)
  end

  def set_params(env_params, env_urls, test_params, test_items, log_limit, proxy)
    @env_params = env_params
    @env_urls = env_urls
    @test_params = test_params
    @test_items = test_items
    @log_limit = log_limit
    @proxy = proxy
  end

  def log_results(scenario, current_test)
    if current_test
      act_resp = prepare_json_to_log(current_test.actual_body)
      error = current_test.error if current_test.error != ''
      error ||= scenario.exception.to_s if scenario.failed? && scenario.exception
      error ||= ''
      result = scenario.failed? ? "Fail" : current_test.test_result.to_s
      resp_too_long = act_resp.length > $excel_cell_limit rescue false
      note = resp_too_long ? 'complete response is too long, only first part is available' : ''
      @report_data.push [current_test.test_id,
                         result,
                         current_test.comment,
                         current_test.test_element,
                         current_test.scenario,
                         Time.now.to_s,
                         @log.first($excel_cell_limit),
                         current_test.url.to_s.first($excel_cell_limit),
                         current_test.request_type,
                         prepare_json_to_log(current_test.request_headers.to_s).to_s.first($excel_cell_limit),
                         prepare_json_to_log(current_test.request_body).to_s.first($excel_cell_limit),
                         prepare_json_to_log(current_test.expected_body).to_s.first($excel_cell_limit),
                         act_resp.to_s.first($excel_cell_limit),
                         prepare_json_to_log(current_test.expected_headers).to_s.first($excel_cell_limit),
                         prepare_json_to_log(current_test.actual_headers).to_s.first($excel_cell_limit),
                         current_test.response_time,
                         current_test.expected_code,
                         current_test.actual_code,
                         error.to_s.first($excel_cell_limit),
                         note]
      awe_log = @log
      awe_log = "\n********* ERROR ********* \n #{error}\n ******************\n" + @log + "\n" if error && error.length > 0
      @report_data_awe_report.push [current_test.test_id, current_test.test_element, current_test.scenario, result, Time.now.to_s, current_test.url.to_s.first($excel_cell_limit), current_test.request_type, prepare_json_to_log(current_test.request_headers.to_s).to_s.first($excel_cell_limit), prepare_json_to_log(current_test.request_body).to_s.first($excel_cell_limit), prepare_json_to_log(current_test.expected_body).to_s.first($excel_cell_limit), act_resp.to_s.first($excel_cell_limit), prepare_json_to_log(current_test.expected_headers).to_s.first($excel_cell_limit), prepare_json_to_log(current_test.actual_headers).to_s.first($excel_cell_limit), current_test.response_time, current_test.expected_code, current_test.actual_code, error.to_s.first($excel_cell_limit), note, awe_log]
    end
    @log = ''
  end

  def create_excel_report
    book = Spreadsheet::Workbook.new
    sheet1 = book.create_worksheet
    save_report = @report_data.length > 1
    if save_report
      for i in 0..@report_data.length - 1
        sheet1.row(i).push i, *@report_data[i]
        save_report = true
      end
      require 'fileutils'
      FileUtils::mkdir_p "#{$my_root}../../awetest_report"
      book.write "#{$my_root}../../awetest_report/_#{$test_suit.sheet_name}_#{Time.now.strftime "%d_%m_%H_%M_%S"}_.xls"
      begin
        create_json_and_html_report
      rescue Exception => e
        p e.message
      end
    end
  end
end

def create_json_and_html_report
  # Create Html Report
  html_string = ''
  html_string << get_html_header_string
  for i in 1..@report_data_awe_report.length - 1
    html_string << write_each_line_to_report(@report_data_awe_report[i], i)
  end
  html_string << get_html_footer_string
  File.open("#{$my_root}../../awetest_report/_#{$test_suit.sheet_name}_#{Time.now.strftime "%d_%m_%H_%M_%S"}.html", 'w') {|file| file.write(html_string)}

  # Create Json Report
  # require 'json'
  json_hash = {}
  for i in 1..@report_data_awe_report.length - 1
    json_hash[i] = {}
    for j in 0...@report_data_awe_report[0].length
      json_hash[i][@report_data_awe_report[0][j]] = @report_data_awe_report[i][j]
    end
  end
  File.open("#{$my_root}../../awetest_report/_#{$test_suit.sheet_name}_#{Time.now.strftime "%d_%m_%H_%M_%S"}.json", 'w') {|file| file.write(json_hash.to_json)}
end

#Updated: Function will ignore the order of elements in the arrays.
#meaning [1,2,3] and [3,1,2]  will be considered as not different
def different?(a, b, bi_directional=true)
  return [a.class.name, nil] if !a.nil? && b.nil?
  return [nil, b.class.name] if !b.nil? && a.nil?

  differences = {}
  a.each do |k, v|
    if special_value(v)
      differences[k] = [v, b[k]] unless validate_special_value(v, b[k])
    else
      if !v.nil? && b[k].nil?
        differences[k] = [v, nil]
        next
      elsif !b[k].nil? && v.nil?
        differences[k] = [nil, b[k]]
        next
      end

      if v.is_a?(Hash)
        unless b[k].is_a?(Hash)
          differences[k] = "Different types #{v.class} <> #{b[k].class} \n #{v.to_s rescue ''} <1> #{b[k].to_s rescue 'Null'}"
          next
        end
        diff = different?(a[k], b[k])
        differences[k] = diff if !diff.nil? && diff.count > 0

      elsif v.is_a?(Array)
        unless b[k].is_a?(Array)
          differences[k] = "Different types #{v.class} <> #{b[k].class} \n #{v.to_s rescue ''} <2> #{b[k].to_s rescue 'Null'}"
          next
        end
        diff = check_arrays(v, b[k])
        differences[k] = diff if diff && diff.count > 0
      else
        differences[k] = [v, b[k]] unless v == b[k]
      end
    end
  end
  return differences if !differences.nil? && differences.count > 0
end

def check_arrays(arr1, arr2)
  diff = nil
  match_val = nil
  if arr2.is_a?(Array)
    count_arr_1 = arr1.count
    count_arr_1 = count_arr_1 - 1 if arr1.include? "NOTHING"
    count_arr_2 = arr2.count
    c = -1
    diff = (0...(arr1.count)).map do |i|
      #arr1.map do |n|
      c += 1
      n = arr1[c]
      if n.is_a?(Hash) && arr2[0]
        diffs = nil
        arr2.each do |val_2|
          if val_2.is_a?(Hash)
            diffs = different?(n.deep_dup, val_2.deep_dup)
          else
            diffs = ["Different types  #{n.class} <> #{val_2.class} \n #{n.to_s rescue ''} <7> #{val_2.to_s rescue 'Null'}"]
          end
          if diffs.nil?
            match_val = val_2
            break
          end
        end
        if diffs.nil?
          arr2.delete_at arr2.index(match_val)
          arr1.delete_at arr1.index(n)
          c = c - 1
        end
        diffs = different?(n, arr2[c]) if diffs && arr2[c].is_a?(Hash)
        ["11.Differences: ", diffs] if diffs
      elsif n.is_a?(Array) && arr2[0]
        diffs = nil
        arr2.each do |nested_array|
          if nested_array.is_a?(Array)
            diffs = check_arrays(n.deep_dup, nested_array.deep_dup)
            unless diffs
              match_val = nested_array
              break
            end
          else
            diffs = "different types #{n.class} <> #{nested_array.class} \n #{n.to_s rescue ''} <9> #{nested_array.to_s rescue 'Null'}"
          end
        end
        unless diffs
          arr2.delete_at arr2.index(match_val)
          arr1.delete_at arr1.index(n)
          c = c - 1
        end
        [n, arr2[c]] if diffs
      elsif special_value(n)
        [n, arr2[c]] unless validate_special_value n, arr2[c]
      else
        arr_val_found = nil
        arr2.each do |val_2|
          arr_val_found = val_2 == n
          if arr_val_found
            match_val = val_2
            break
          end
        end
        if arr_val_found
          arr2.delete_at arr2.index(match_val)
          arr1.delete_at arr1.index(n)
          c = c - 1
        end
        [n, arr2[c]] unless arr_val_found
      end
    end.compact

    if count_arr_1 > count_arr_2
      diff ||= []
      diff << ["Missing #{count_arr_1 - count_arr_2} elements in the array, expected #{count_arr_1}, got #{count_arr_2} "]
    end
  else
    diff = ["Different types  #{arr1.class} <> #{arr2.class} \n #{arr1.to_s rescue ''} <10> #{arr2.to_s rescue 'Null'}"]
  end
  diff if diff && diff.count > 0
end

def special_value(v)
  result = false
  if v && v.is_a?(String)
    case v
      when *$validation_keys
        result=true
    end
  end
  result
end


#string string to replace params in
#hashes, an array of hashes with params.
#request_string to tell if the string is used for request to call generate_values function only for request strings
def replace_params(string, hashes, request_string = false, prefix='', in_quotes = true) #(keys)
  return string unless string.is_a?(String)
  original = string.dup
  hashes.each {|hash|
    hash = hashes if hashes.is_a?(Hash)
#will replace all the params in test items hash with they special capital values in the request and header and response
# all keys in the request and response that will be replaced must be in quotes and all caps ex: "TOKENREQUESTORID"
    return string unless string.is_a? String

    in_string = !can_parse_json(string)
    string = apply_no_key_value string

#check if no initial hash is passed, so that we will use test_items hash as a hash with values that we will replace
#check if we want to use test_items to replace params that we are storing for a specific item
    if prefix !~ /item_/ && hash.is_a?(Array) && (string.include?("\"item_"))
      #prefix = 'item_'
      #replace params for each item in the test_items hash
      #ALL items specific keys to be replaced  must have item_#  before the actual value

      hash.each_with_index {|item_hash, index|
        string = replace_params string, item_hash, request_string, "#{'item_'}#{index+1}_", in_quotes
      }
      #prefix = ''
    end
    if in_quotes && hash.is_a?(Hash)
      #Actuall replacing loop, goes through the hash and replaces
      hash.each {|key, value|
        if value.nil?
          string = string.gsub("\"#{prefix + key.upcase}\"", 'null')
        else
          if value.is_a?(String) && !in_string
            string = string.gsub("\"#{prefix + key.upcase}\"", "\"#{value}\"")
          else
            value = value.to_json unless value.is_a?(String)
            string = string.gsub("\"#{prefix + key.upcase}\"", value)
          end
        end
      }
    elsif hash.is_a?(Hash)
      keys = hash.keys.sort_by {|x| -x.length}
      keys.each {|key|
        value = hash[key]
        value = 'null' if value.nil?
        value = value.to_json unless value.is_a?(String)
        original_2 = string.dup
        string = string.gsub("#{prefix + key.upcase}", value) #unless in_string
        if can_parse_json(string) && !can_parse_json(original_2)
          string = replace_params(string, hashes, request_string, prefix, true)
        end
        string = replace_params(string, hashes, request_string, prefix, in_quotes) if original != string
      }
    end
    break if hashes.is_a?(Hash)
  }
  generate_values(string) if original != string && request_string
  string = replace_params(string, hashes, request_string, prefix, in_quotes) if original != string
  string = replace_params(string, hashes, request_string, prefix, false) if in_quotes
  string
end

def can_parse_json(string)
  result = false
  begin
    JSON.parse(string)
    result = true
  rescue
    result = false
  end
  result
end


def call_and_fail_gracefully(client, *args, &block)
  client.call(*args, &block)
rescue Savon::SOAPFault => e
  # {"Error" => e.message}
    e
rescue Exception => e
  # {"Error" => e.message}
  e
end


def get_soap_client(url)
  $request_timeout ||= 180
  client = Savon.client(
      # The WSDL document provided by the service.
      :wsdl => url,

      # Lower timeouts so these specs don't take forever when the service is not available.
      :open_timeout => $request_timeout,
      :read_timeout => $request_timeout,

      # Disable logging for cleaner spec output.
      :log => false
  )
  return client
end


def generate_xml(data, parent = false, opt = {})
  require 'nokogiri'
  return if data.to_s.empty?
  return unless data.is_a?(Hash)

  unless parent
    # assume that if the hash has a single key that it should be the root
    root, data = (data.length == 1) ? data.shift : ["root", data]
    builder = Nokogiri::XML::Builder.new(opt) do |xml|
      xml.send(root) {
        generate_xml(data, xml)
      }
    end

    return builder.to_xml
  end

  data.each {|label, value|
    if value.is_a?(Hash)
      attrs = value.fetch('@attributes', {})
      # also passing 'text' as a key makes nokogiri do the same thing
      text = value.fetch('@text', '')
      parent.send(label, attrs, text) {
        value.delete('@attributes')
        value.delete('@text')
        generate_xml(value, parent)
      }

    elsif value.is_a?(Array)
      value.each {|el|
        # lets trick the above into firing so we do not need to rewrite the checks
        el = {label => el}
        generate_xml(el, parent)
      }

    else
      parent.send(label, value)
    end
  }
end


def xml_string_to_hash(xml_string)
  require 'active_support/core_ext/hash'
  require 'nokogiri'
  doc = Nokogiri::XML(xml_string)
  Hash.from_xml(doc.to_s)
end



def key_value_of_xml_string(xml_string)
  tmp_strings = xml_string.split "\n"
  @matrix = []
  if tmp_strings.length > 1
    for tmp_string in tmp_strings
      matrix = get_matrix(tmp_string)
    end
  else
    get_matrix(xml_string)
  end
  @matrix
end


def get_matrix(tmp_string)
  index_of_first_open_diamond = tmp_string.index('<')
  index_of_second_open_diamond = tmp_string.index('<', 1)
  index_of_first_close_diamond = tmp_string.index('>')
  key = tmp_string[index_of_first_open_diamond+1...index_of_first_close_diamond]
  value = tmp_string[index_of_first_close_diamond+1...index_of_second_open_diamond]
  @matrix.push([key, value, tmp_string])
end


def xmlns_link(xml_string)
  if xml_string.include?('xmlns')
    xml_string.split('xmlns')[0].split('<')[1]
  end
end


def replace_xml_node(original_text, replace_text)
  require 'nokogiri'
  replace_matrix = key_value_of_xml_string(replace_text)
  row_len = replace_matrix.length
  if row_len > 1
    for i in 0...row_len
      replace_pair = replace_matrix[i]
      replace_key = replace_pair[0]
      replace_value = replace_pair[1]
      replace_string = replace_pair[2]
      original_doc, original_text = get_original_doc(replace_key, replace_value, replace_string, original_text)
    end
  else
    replace_pair = replace_matrix[0]
    replace_key = replace_pair[0]
    replace_value = replace_pair[1]
    replace_string = replace_pair[2]
    original_doc, original_text = get_original_doc(replace_key, replace_value, replace_string, original_text)
  end

  if original_doc.to_s.include?("&amp")
    original_replaced = original_doc.to_s.gsub(/&amp;/, "&")
    original_doc = Nokogiri::XML(original_replaced)
    original_doc.to_xml
  else
    original_doc.to_xml
  end
end


def get_original_doc(replace_key, replace_value, replace_string, original_text)
  begin
    original_doc = Nokogiri::XML(original_text)
    replace_node = original_doc.xpath('//' + replace_key)[0]
    # replace_node = original_doc.xpath('//' + replace_key.split('')[0])[0]
    replace_node.content = replace_value
  rescue
    tag_name = xmlns_link(replace_string)
    req_1 = original_text.split replace_key
    new_req = req_1[0] + replace_key
    tmp_val = req_1[1].split("</#{tag_name}>")[1]
    new_req = new_req + ">" + replace_value + "</#{tag_name}>" + tmp_val
    original_doc = Nokogiri::XML(new_req)
    original_text = new_req
  end
  [original_doc, original_doc.to_xml.to_s]
end


#If the value we capture does not has the same type every time. and we capture multiple times, It will store up to 2 values of different type.
# the original key will have the last value and the key_ will have the previously stored value of a different type.
#this is so that we can store and array and an object at the same time when we get different value types of in the result of the object
def capture_test_params(act_par, capture_to_hash)
  if act_par.is_a? Hash
    act_par.each_key {|key|
      if act_par[key].is_a? Hash
        capture_test_params(act_par[key], capture_to_hash)
      elsif act_par[key].is_a?(Array) && act_par[key][0].is_a?(Hash)
        act_par[key].each {|hash|
          if hash.is_a?(Hash)
            capture_test_params(hash, capture_to_hash)
          end
        }
      elsif act_par[key].is_a?(Array) && act_par[key][0].is_a?(Array)
        act_par[key].each {|array|
          array.each {|hash|
            if hash.is_a?(Hash)
              capture_test_params(hash, capture_to_hash)
            end
          }
        }
      end
      case key.to_s
        when *$capture_params
          capture_to_hash.deep_merge!({key.to_s => act_par[key]}) if act_par[key]
      end}
  end
end

def load_test_suit(excel_file_name, sheet_name, test_data=nil)
  unless test_data && test_data.excel_file_name == excel_file_name && test_data.sheet_name == sheet_name
    test_data = APITestSuit.new(excel_file_name, sheet_name)
  end
  test_data
end


def capture_by_path(act_par, capture_to_hash, capture_only_key = nil)
  $capture_paths.keys.each do |capture_key|
    next if capture_only_key && capture_only_key != capture_key
    capture_path = $capture_paths[capture_key]
    next_value = act_par
    capture_path.each_with_index do |path_key, index|
      if index == 0 && path_key.is_a?(Integer) && next_value.is_a?(Hash)
        next_value = next_value["arrayResponse"]
      end
      if (next_value.is_a?(Array) && path_key.is_a?(Integer)) || next_value.is_a?(Hash)
        next_value = next_value[path_key] || next_value[path_key.to_sym] rescue nil
      elsif next_value && path_key == 'integer'
        next_value = next_value.to_s.reverse
        next_value = next_value[(next_value =~ /[0-9]/)..-1] rescue '0'
        last_num = (next_value =~ /[^\d]/) - 1 rescue nil
        last_num ||= -1
        next_value = next_value[0..last_num].reverse.to_i
      else
        next_value = nil
        break
      end
    end
    if next_value
      capture_to_hash[capture_key] = next_value
    end
  end
end

def apply_no_key_value (string)
  if string && string.include?("NO_K_V")
    hash = JSON.parse(string)
    hash = apply_no_key_value_helper(hash)
    string = hash.to_json
  end
  string
end

def apply_no_key_value_helper(hash)
  hash.each_key do |key|
    if hash[key].is_a? String
      hash.delete(key) if hash[key]== "NO_K_V"
    elsif hash[key].is_a? Hash
      apply_no_key_value_helper(hash[key])
    elsif hash[key].is_a? Array
      hash.delete(key) if hash[key][0]== "NO_K_V"
      if hash[key][0].is_a? Hash
        hash[key].each do |sub_hash|
          apply_no_key_value_helper(sub_hash)
        end
      end
    end
  end
end

#The function will merge 2 hashes and if it includes Arrays of objects, it will merge the objects within the array
def deep_merge_custom(hash_1, hash_2)
  hash_1.deep_merge(hash_2) {|key, val_1, val_2|
    if val_1.is_a?(Array) && val_2.is_a?(Array) && val_1[0].is_a?(Hash) && val_2[0].is_a?(Hash)
      new_arr = []
      val_2.each_with_index {|value, index|
        val_1[index] ||= {}
        new_arr[index] = deep_merge_custom(val_1[index], val_2[index])
      }
      new_arr
    else
      val_2
    end
  }
end

def prepare_json_to_log(json)
  if json.is_a? Array
    result = ''
    json.each do |item|
      result << prepare_json_to_log(item)
    end
    json = result
  else
    json = JSON.parse(json) rescue json
    if json.is_a? Hash
      json = delete_big_values_helper(json) if $trim_values_limit
      json = JSON.pretty_generate json, indent: "    ", space: ""
    end
  end
  json
end

def delete_big_values_helper(json)
  if json.is_a? Hash
    json.each_key {|key|
      if json[key].is_a? String
        json[key] = json[key].first($trim_values_limit[1]) + '...' if json[key].length > $trim_values_limit[0]
      elsif json[key].is_a?(Hash) || json[key].is_a?(Array)
        json[key] = delete_big_values_helper(json[key])
      end
    }
  elsif json.is_a? Array
    json.each do |array_item|
      delete_big_values_helper array_item
    end
  end
  json
end

def get_html_header_string
  return '<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1"/>
    <title>Awetest Service Report</title>
    <link href="http://awetest.com/favicon.ico" rel="shortcut icon">

    <script src="https://awetest.com/assets/test_base/service_api_log.js" type="text/javascript"></script>
    <link href="https://awetest.com/assets/service_report.css" media="screen" rel="stylesheet" type="text/css">
    <script src="https://awetest.com/assets/jquery.js"   type="text/javascript"></script>
    <script src="https://awetest.com/assets/clipboard.min.js"   type="text/javascript"></script>
    <script src="https://awetest.com/assets/Chart.js"   type="text/javascript"></script>
    <script type="text/javascript" src="http://awetest.com/system/downloads/Report/awetest_part.js"></script>
    <script type="text/javascript" src="http://awetest.com/system/downloads/Report/json2xml.js"></script>
    <script type="text/javascript" src="http://awetest.com/system/downloads/Report/highlight.pack.js"></script>
    <!--[if IE]>
    <style>
        .inner-table-wrapper {
            position: relative;
            left: -1px;
        }
    </style>
    <![endif]-->

</head>
<body>
<header class="header"></header>
<div class="left-tab"></div>
<div class="wrapper">
    <div class="content">
        <div class="row">
            <div class="gl_page_inner">
                <div class="gl_hr_header">
                    <div class="header-element"><a href="" class="header-element-link">Test Report</a></div>
                </div>
                <div class="design-body">
                    <div class="information-block">
                        <div class="inf-bottom-part">
                            <div class="main-info-wrapper">
                                <div>
                                    <span class="sprite sprite-i-multi-storey-building-white"></span>Total Time: <span id="total-time"></span> Seconds
                                </div>
                                <div>
                                    <span class="sprite sprite-i-multi-storey-building-white"></span># of Scenarios: <span id="total-scenario-number"></span>
                                </div>
                                <div>
                                    <span class="sprite sprite-i-multi-storey-building-white"></span>
                                </div>
                                <div><span class="sprite sprite-i-multi-storey-building-white"></span># Passed: <span id="passed-scenario-number"></span></div>
                                <div>
                                    <span class="sprite sprite-i-multi-storey-building-white"></span>
                                </div>
                                <div><span class="sprite sprite-i-multi-storey-building-white"></span>Pass %: <span id="pass-percentage"></span></div>
                            </div>
                            <div class="chart-wrapper">
                                <canvas id="chart1" height="120px" width="120px"></canvas>
                                <div class="chartjs-tooltip" id="chart-tooltip"></div>
                                <div id="spfg_legend"></div>
                            </div>
                        </div>
                    </div>

                    <div class="information-table">
                        <div class="table-control-row">
                            <p class="active left-control expand-button closed" data-target="all">EXPAND ALL</p>
                            <p class="right-control toggle-errors active">ALL</p>
                            <p class="right-control toggle-errors">ERRORS</p>
                            <p class="right-control">SHOW</p>
                        </div>

                        <table class="inf-table">
                            <thead class="table-head">
                                <tr>
                                    <th width="39">#</th>
                                    <th width="150">ID</th>
                                    <th width="121">URL</th>
                                    <th width="160">Scenario</th>
                                    <th width="96">Date/Time</th>
                                    <th width="67">Method</th>
                                    <th width="90">Duration</th>
                                    <th width="86">Exp Code</th>
                                    <th width="86">Actual Code</th>
                                    <th width="88">Result</th>
                                </tr>
                            </thead>

                            <tbody>'
end

def write_each_line_to_report (report_line, i, xml_in_log=false)
  result_string = ""

  if report_line[3] == 'Pass'
    result_string << "<tr class='pass scenario' id='scenario#{i}'>"
  else
    result_string << "<tr class='fail scenario' id='scenario#{i}'>"
  end

  result_string << "
                                    <td width='39'>
                                        <div class='jump-wrapper'>
                                            <div data-destination='#scenario#{i-1}'>↑</div>
                                            <div data-destination='#scenario#{i+1}'>↓</div>
                                        </div>
                                        <span class='expand-button closed' data-target='.expand-#{i}'></span>#{i}
                                    </td>
                                    <td width='80'>#{report_line[0]}</td>
                                    <td width='121'><a href='#{report_line[5]}' class='table-link'>#{report_line[5]}</a></td>
                                    <td width='235'>#{report_line[2]}</td>
                                    <td width='96'>#{report_line[4]}</td>
                                    <td width='67'>#{report_line[6]}</td>
                                    <td width='90' class='single-scenario-time'>#{report_line[13]}</td>
                                    <td width='86'>#{report_line[14]}</td>
                                    <td width='86'>#{report_line[15]}</td>"

  if report_line[3] == 'Pass'
    result_string << "<td width='90' class='result-pass result-count pass-count'><span class='sprite sprite-i-passed-green'></span>#{report_line[3]}</td>"
  else
    result_string << "<td width='90' class='result-fail result-count fail-count'><span class='sprite sprite-i-failed-red'></span>#{report_line[3]}</td>"
  end

  result_string << "<tr class='expand-row'>
      <td class='no-padding no-border' colspan='10'>
          <div class='inner-table-wrapper expand-#{i} hide'>"

  if 1 + 1 > 2
    result_string << "<div class='comment-text'>What is this?
              </div>"
  end

  result_string << "<span class='tab-toggle summary active' data-target='summary'>Summary</span>
                    <span class='tab-toggle log' data-target='log'>Log</span>
                    <span class='tab-toggle xml' data-target='xml'>Xml</span>"

    result_string << "<table class='inf-table tab-content' id='summary-#{i}'>
                  <tr>
                      <th>Request</th>
                      <th>Expected Response</th>
                      <th>Actual Response</th>
                  </tr>
                  <tr>
                    <td>
                        <div class='tooltip copy-to-clipboard'>
                            <div class='sprite sprite-i-list-grey ripplelink'></div>
                            <div class='tooltip-inner'>
                                <div class='tooltip-ir-inner'>
                                    Copy to clipboard
                                </div>
                            </div>
                        </div>
                        <div class='json-wrapper'>
                            Headers<br>
                            <pre>#{report_line[7]}</pre>
                        </div>
                    </td>
                    <td>
                        <div class='tooltip copy-to-clipboard'>
                            <div class='sprite sprite-i-list-grey ripplelink'></div>
                            <div class='tooltip-inner'>
                                <div class='tooltip-ir-inner'>
                                    Copy to clipboard
                                </div>
                            </div>
                        </div>
                        <div class='json-wrapper'>
                            Headers<br>
                            <pre>#{report_line[11]}</pre>
                        </div>
                    </td>
                    <td>
                        <div class='tooltip copy-to-clipboard'>
                            <div class='sprite sprite-i-list-grey ripplelink'></div>
                            <div class='tooltip-inner'>
                                <div class='tooltip-ir-inner'>
                                    Copy to clipboard
                                </div>
                            </div>
                        </div>
                        <div class='json-wrapper'>
                            Headers<br>
                            <pre>#{report_line[12]}</pre>
                        </div>
                    </td>
                  </tr>
                  <tr>
                      <td>
                          <div class='tooltip copy-to-clipboard'>
                              <div class='sprite sprite-i-list-grey ripplelink'></div>
                              <div class='tooltip-inner'>
                                  <div class='tooltip-ir-inner'>
                                      Copy to clipboard
                                  </div>
                              </div>
                          </div>
                          <div class='json-wrapper'>
                              Body<br>
                              <pre>#{report_line[8]}</pre>
                          </div>
                      </td>
                      <td>
                          <div class='tooltip copy-to-clipboard'>
                              <div class='sprite sprite-i-list-grey ripplelink'></div>
                              <div class='tooltip-inner'>
                                  <div class='tooltip-ir-inner'>
                                      Copy to clipboard
                                  </div>
                              </div>
                          </div>
                          <div class='json-wrapper'>
                              Body<br>
                              <pre>#{report_line[9]}</pre>
                          </div>
                      </td>
                      <td>
                          <div class='tooltip copy-to-clipboard'>
                              <div class='sprite sprite-i-list-grey ripplelink'></div>
                              <div class='tooltip-inner'>
                                  <div class='tooltip-ir-inner'>
                                      Copy to clipboard
                                  </div>
                              </div>
                          </div>
                          <div class='json-wrapper'>
                              Body<br>
                              <pre>#{report_line[10]}</pre>
                          </div>
                      </td>
                  </tr>
                </table>"

  result_string << "<table class='inf-table tab-content hide' id='log-#{i}'>
                      <tr><td><div style='max-height:500px; overflow: auto;
  margin-bottom: 10px;'><pre>#{''.html_safe + report_line[18].to_s}</pre></div></td></tr>
                    </table>"


  result_string << "
              <table class='inf-table tab-content hide' id='xml-#{i}'>
                  <tr>
                      <th>Request</th>
                      <th>Expected Response</th>
                      <th>Actual Response</th>
                  </tr>"

  if report_line[3] == 'Pass'
  elsif 1 + 1 > 2
    result_string << "<tr>
                        <td class='error-row' colspan='3'>Error: TODO</td>
                      </tr>"
  else
  end

  result_string << "<tr>
                      <td>
                          <div class='tooltip copy-to-clipboard'>
                              <div class='sprite sprite-i-list-grey ripplelink'></div>
                              <div class='tooltip-inner'>
                                  <div class='tooltip-ir-inner'>
                                      Copy to clipboard
                                  </div>
                              </div>
                          </div>
                          <div class='json-wrapper'>
                              Headers<br>
                              <div class='json-to-xml'>#{report_line[7]}</div>
                          </div>
                      </td>
                      <td>
                          <div class='tooltip copy-to-clipboard'>
                              <div class='sprite sprite-i-list-grey ripplelink'></div>
                              <div class='tooltip-inner'>
                                  <div class='tooltip-ir-inner'>
                                      Copy to clipboard
                                  </div>
                              </div>
                          </div>
                          <div class='json-wrapper'>
                              Headers<br>
                              <div class='json-to-xml'>#{report_line[11]}</div>
                          </div>
                      </td>
                      <td>
                          <div class='tooltip copy-to-clipboard'>
                              <div class='sprite sprite-i-list-grey ripplelink'></div>
                              <div class='tooltip-inner'>
                                  <div class='tooltip-ir-inner'>
                                      Copy to clipboard
                                  </div>
                              </div>
                          </div>
                          <div class='json-wrapper'>
                              Headers<br>
                              <div class='json-to-xml'>#{report_line[12]}</div>
                          </div>
                      </td>
                  </tr>
                  <tr>
                      <td>
                          <div class='tooltip copy-to-clipboard'>
                              <div class='sprite sprite-i-list-grey ripplelink'></div>
                              <div class='tooltip-inner'>
                                  <div class='tooltip-ir-inner'>
                                      Copy to clipboard
                                  </div>
                              </div>
                          </div>
                          <div class='json-wrapper'>
                              Body<br>
                              <div class='json-to-xml'>#{report_line[8]}</div>
                          </div>
                      </td>
                      <td>
                          <div class='tooltip copy-to-clipboard'>
                              <div class='sprite sprite-i-list-grey ripplelink'></div>
                              <div class='tooltip-inner'>
                                  <div class='tooltip-ir-inner'>
                                      Copy to clipboard
                                  </div>
                              </div>
                          </div>
                          <div class='json-wrapper'>
                              Body<br>
                              <div class='json-to-xml'>#{report_line[9]}</div>
                          </div>
                      </td>
                      <td>
                          <div class='tooltip copy-to-clipboard'>
                              <div class='sprite sprite-i-list-grey ripplelink'></div>
                              <div class='tooltip-inner'>
                                  <div class='tooltip-ir-inner'>
                                      Copy to clipboard
                                  </div>
                              </div>
                          </div>
                          <div class='json-wrapper'>
                              Body<br>
                              <div class='json-to-xml'>#{report_line[10]}</div>
                          </div>
                      </td>
                  </tr>
              </table>
          </div>
      </td>
  </tr>"

  result_string
end

def get_html_footer_string
  '
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

<div id="return-to-top"><i class="sprite sprite-i-dropdown-grey"></i></div>

<script type="text/javascript">
    function formatXml(xml) {
        var formatted = "";
        var reg = /(>)(<)(\/*)/g;
        xml = xml.replace(reg, "$1\r\n$2$3");
        var pad = 0;
        jQuery.each(xml.split("\r\n"), function(index, node) {
            var indent = 0;
            if (node.match( /.+<\/\w[^>]*>$/ )) {
                indent = 0;
            } else if (node.match( /^<\/\w/ )) {
                if (pad != 0) {
                    pad -= 1;
                }
            } else if (node.match( /^<\w[^>]*[^\/]>.*$/ )) {
                indent = 1;
            } else {
                indent = 0;
            }

            var padding = "";
            for (var i = 0; i < pad; i++) {
                padding += "  ";
            }

            formatted += padding + node + "\r\n";
            pad += indent;
        });

        return formatted;
    }

    var totalScenarioNumber = $(".result-count").length;
    var passedScenarioNumber = $(".result-count.pass-count").length;
    var passPercentage = (passedScenarioNumber * 100 / totalScenarioNumber).toFixed(2) + "%";
    $("#total-scenario-number").html(totalScenarioNumber);
    $("#passed-scenario-number").html(passedScenarioNumber);
    $("#pass-percentage").html(passPercentage);
    var totalTimeInSecond = 0;
    $(".single-scenario-time").each(function () {
        var timeText = $(this).html();
        totalTimeInSecond += Number(timeText.split(" ")[0]);
    });
		var totalTimeInSec = Math.round(totalTimeInSecond);
    $("#total-time").html(totalTimeInSec);

    $(".json-to-xml").each(function () {
        var validJson = false;
        var originalJson = $(this).text();
        var preParseJson = originalJson.replace(/=>/g, ":");
        var realJson = preParseJson;
        try {
            realJson = JSON.parse(preParseJson);
            validJson = true;
        }
        catch (err) {
            console.log(err.message);
        }
        if (validJson == true) {
            var finalXml = realJson;
            try {
                finalXml = json2xml(realJson);
            }
            catch (err) {
                console.log(err.message);
            }
            var xmlHead = "<pre><code class=\"xml\">";
            var xmlTail = "</code></pre>";
            var lol = (formatXml(finalXml));
            var replacedFinalXml = lol.replace(/>/g, "&gt;").replace(/</g, "&lt;").replace(/"/g, "&quot;");
  $(this).html(xmlHead + replacedFinalXml + xmlTail);
  }
  });
  hljs.initHighlightingOnLoad();
  </script>
</body>
</html>'
end
