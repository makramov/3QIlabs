$lock = Mutex.new

def run_performance_test(params, with_data = false)
  if !$performance_test_started
    $http_tool = :typhoeus
    require 'typhoeus' #fastest gem using curl for performance
    $performance_test_started = true
    $request_total_attempts = params["request_retry_attempts"].to_i + 1
    duration_seconds = params["duration_minutes"].to_i * 60
    num_of_threads = params["threads_number"].to_i
    max_loops = params["max_loops"].to_i
    evenly_increment_by = params["evenly_increment_by"].to_i # increment by this number of threads and spread acrros the whole run
    increment_by_thread_num = params["increment_by_thread_num"].to_i
    increment_every_num_seconds =params["increment_every_num_seconds"].to_i
    $log_all_requests = params["log_all_requests"] == "true"

    if duration_seconds == 0 && max_loops == 0
      fail("No duration given OR no max number of loops given")
    end
    if num_of_threads ==0
      fail ("No maximum number of threads given")
    end
    test_ids ||= $test_suit.data.keys
    test_ids.shift
    test_params = []
    num_of_threads.times do
      test_params << {}
    end
    if with_data
      num_of_threads.times do |i|
        test_params[i] = $test_suit.merge_row_data(i+1, {})
      end
    end
    get_test_params_performance(test_params)
    jobs = []
    $finish_now = false


    threads_increment_by = evenly_increment_by + increment_by_thread_num
    total_threads = num_of_threads
    if threads_increment_by != 0
      num_of_threads = threads_increment_by
    end
    number_of_increments = total_threads/num_of_threads

    test_end_time = Time.now + duration_seconds
    test_end_time = 0 if duration_seconds == 0
    if increment_every_num_seconds == 0 && number_of_increments != 1 #increment evenly
      sleep_before_increment_seconds = duration_seconds/number_of_increments
    else
      sleep_before_increment_seconds = increment_every_num_seconds
    end
    $total_threads_num = 0
    $performance_report = {}
    $performance_report_steps = {}
    book = Spreadsheet::Workbook.new
    summary_sheet = book.create_worksheet :name => "summary"
    master_sheet = book.create_worksheet :name => "master_sheet"
    details_sheet = book.create_worksheet :name => "step_details"
    master_sheet.row(0).push "Time","# of Threads", "Thread#","run#", "flow_result","throughput", *test_ids
    details_sheet.row(0).push "Time", "# of Threads","Thread#","run#", "test_id", "attempt#", "time(s)","flow_result", "Result","overhead",'bytes_received', 'bytes_sent',"Type", "URL", "Header", "Request", "Code", "Act_Response", "Act_Header", "Act_code", "Error","Logs", "RetryAttempts"
    summary_sheet.row(0).push "Test ID","# Requests","Average", "Min", "Max", "Std. Dev", "Error %", "Avg. Throughput", 'Sent KB/s',"Recieved KB/s", "Average Bytes"

    puts "Performance test will start at #{Time.now.to_s} and end at #{test_end_time.to_s} or until ran #{max_loops} iterations "
    if number_of_increments > 1
      puts "Adding #{num_of_threads} threads every #{sleep_before_increment_seconds} seconds"
    end
    puts "For max. number of threads: #{total_threads}"
    test_start_time = Time.now
    number_of_increments.times do |i|
    if !$finish_now
      jobs.push(Thread.new{
                  begin
                    exec_job(i+1, $env,$test_suit,test_ids,num_of_threads,test_params,test_end_time, max_loops)
                  rescue => e
                    puts e.to_s
                    puts e.backtrace
                  end
                })
      $lock.synchronize{$total_threads_num += num_of_threads}
      sleep sleep_before_increment_seconds
      #puts "waited #{sleep_before_increment_seconds} seconds"
    end
    end

    jobs.each do |job|
      job.join
    end

    #in case we stopped earlier than we expected to
    duration_seconds = (Time.now - test_start_time).to_i

    max_exel_rows = 65000
    sheet_count = 1
    throughput_data = []
    throughput_hash = {}

    $performance_report.keys.sort.each_with_index do |key, index|
      num_of_threads = $performance_report[key][1]
      #throughput_hash[num_of_threads] ||= []
     # throughput_hash[num_of_threads] <<  $performance_report[key][5].round(1)
      master_sheet.row(index+1-((sheet_count-1)*max_exel_rows)).push *$performance_report[key]
      if index >= max_exel_rows*sheet_count
        sheet_count = sheet_count + 1
        master_sheet = book.create_worksheet :name => "master_sheet#{sheet_count}"
        master_sheet.row(0).push "Time","# of Threads", "Thread#","run#", "flow_result","throughput", *test_ids
      end
    end
    sheet_count = 1
    $performance_report_steps.keys.sort.each_with_index do |key, index|
      details_sheet.row(index+1-((sheet_count-1)*max_exel_rows)).push *$performance_report_steps[key]
      if index >= max_exel_rows*sheet_count
        sheet_count = sheet_count + 1
        details_sheet = book.create_worksheet :name => "step_details#{sheet_count}"
        details_sheet.row(0).push "Time", "# of Threads","Thread#","run#", "test_id", "attempt#", "time(s)","flow_result", "Result","overhead", 'bytes_received', 'bytes_sent', "Type", "URL", "Header", "Request", "Code", "Act_Response", "Act_Header", "Act_code", "Error","Logs", "RetryAttempts"
      end
    end

    report_data_tests = {}


    response_time_over_threads_data = []
    response_time_over_threads = {}
    chart_over_time_data = []
    test_ids.count.times do |i|
      chart_over_time_data[i] = []
      response_time_over_threads_data[i] = []
      response_time_over_threads[i] = {}
    end
    thread_data = []
    threads_data_hash = {}
    max_thread_number = 0
    $performance_report_steps.keys.each_with_index do |key, index|
      $performance_report_steps[key]
      time = $performance_report_steps[key][0]
      time = (time.to_f*1000).to_i
      num_of_threads = $performance_report_steps[key][1]
      if num_of_threads >= max_thread_number
        max_thread_number = num_of_threads
        threads_data_hash[num_of_threads] ||= {}
        threads_data_hash[num_of_threads]["start_time"] ||= time
        threads_data_hash[num_of_threads]["end_time"] = time
        threads_data_hash[num_of_threads]["request_count"] ||= 0
        threads_data_hash[num_of_threads]["request_count"] += 1
      end
      test_id = $performance_report_steps[key][4]
      i = test_ids.index(test_id)
      test_time = $performance_report_steps[key][6]
      test_result = $performance_report_steps[key][8] == "true"
      bytesize =  $performance_report_steps[key][10]
      bytesize_sent = $performance_report_steps[key][11]
      chart_over_time_data[i] << [time,test_time]
      response_time_over_threads[i][num_of_threads] ||= []
      response_time_over_threads[i][num_of_threads] << test_time
      thread_data << [time, $performance_report_steps[key][1]] if i == 0 || ($performance_report_steps.count-1 ==index)

      report_data_tests[test_id] ||= {"time"=>[],"bytesize"=>[],"bytesize_sent"=>[], "result"=>{"pass"=>0,"fail"=>0}}
      report_data_tests[test_id]["time"] <<test_time if test_time > 0
      report_data_tests[test_id]["bytesize"] <<bytesize if bytesize > 0
      report_data_tests[test_id]["bytesize_sent"] << bytesize_sent if bytesize_sent > 0
      if test_result
          report_data_tests[test_id]["result"]["pass"] = report_data_tests[test_id]["result"]["pass"] + 1
      else
        report_data_tests[test_id]["result"]["fail"] = report_data_tests[test_id]["result"]["fail"] + 1
      end

    end
    threads_data_hash.keys.sort.each do |key|
      throughput_duration_s = (threads_data_hash[key]["end_time"]-threads_data_hash[key]["start_time"])/1000
      request_count_throughput = threads_data_hash[key]["request_count"]
      tp = (request_count_throughput/throughput_duration_s.to_f).round(1)
      throughput_hash[key] = [tp]
    end

    response_time_over_threads[response_time_over_threads.count] = throughput_hash
    response_time_over_threads.keys.each do |test_num|
      response_time_over_threads[test_num].keys.sort.each do |num_threads|
        response_times = response_time_over_threads[test_num][num_threads]
        aver_time = response_times.sum/response_times.count
        aver_time = aver_time.round(1) if aver_time.is_a? Float
        exist_all = true
          response_time_over_threads.keys.each do |test_num_2|
            #remove data if we don't have data for all of the operations
            exist_all = exist_all && response_time_over_threads[test_num_2][num_threads] && !response_time_over_threads[test_num_2][num_threads].empty?
          end
        response_time_over_threads_data[test_num] ||= []
        response_time_over_threads_data[test_num] << [num_threads, aver_time] if exist_all
      end
    end


    chart_over_time_data[chart_over_time_data.count] = thread_data
    #chart_over_time_data[chart_over_time_data.count] = throughput_data
    #this will limit number of records in the chart by taking averages of numbers close to each other
    #increasing the time chart loads
    chart_over_time_data.each do |data_array|
      while data_array.count > 1000
        data_array2 = []
            for i in 1...data_array.count
              x = i-1
               if (i%2 == 1) && data_array[i]
                 a = data_array[i]
                 b = data_array[x]
                 value = (a[1] + b[1])/2
                 value = value.round(1) if value.is_a? Float
                 data_array2 << [(a[0] + b[0])/2, value]
               end
            end
        data_array.clear
        data_array.concat data_array2
      end
    end

    data_columns = (test_ids.deep_dup << "Number Of Threads")
    chart_over_time = ChartClass.new(chart_over_time_data, data_columns, "all_over_time")
    threads_over_time = ChartClass.new([thread_data], ["Number Of Threads"], "threads_over_time")
    data_columns = (test_ids.deep_dup << "Throughput r/s")
    time_over_threads = ChartClass.new(response_time_over_threads_data, data_columns, "time_over_threads")

    chart_over_time.add_data_strings
    chart_over_time.add_series
    threads_over_time.add_data_strings
    threads_over_time.add_series
    time_over_threads.add_data_strings
    time_over_threads.add_series
    #chart_over_threads = ChartClass.new(chart_over_time_data, test_ids,duration_seconds*1000)
    #chart_over_threads.set_threads_data(thread_data)
    index = 1
    total_requests_count = 0
    average_list = []
    min_list = []
    max_list = []
    std_list = []
    error_rate_list = []
    aver_bytes_list = [] #average of bytes received per request
    received_kb_s_list = [] #received kb per second
    sent_kb_s_list = [] #sent kb per second
    summary_table = SummaryTable.new
    report_data_tests.keys.each do |key|
      time_list = report_data_tests[key]["time"]
      bytesize_list = report_data_tests[key]["bytesize"]
      aver_bytes = bytesize_list.sum/bytesize_list.size
      aver_bytes_list << aver_bytes
      received_kb_s = ((bytesize_list.sum/duration_seconds)/1000.0).round(2)
      received_kb_s_list << received_kb_s
      bytesize_sent_list = report_data_tests[key]["bytesize_sent"]
      sent_kb_s = ((bytesize_sent_list.sum/duration_seconds)/1000.0).round(2)
      sent_kb_s_list << sent_kb_s
      requests_count = time_list.count
      total_requests_count = total_requests_count + requests_count
      average_time = (time_list.sum / time_list.size)
      average_list << average_time
      min_time = time_list.min
      min_list << min_time
      max_time = time_list.max
      max_list << max_time
      std_dev = standard_deviation(time_list).to_i
      std_list << std_dev
      error_rate =  ((report_data_tests[key]["result"]["fail"]/requests_count.to_f)*100).round(2)
      error_rate_list << error_rate
      error_rate = error_rate.to_s + "%"
      throughput = (requests_count/duration_seconds.to_f).round(1)
      throughput = throughput.to_s + "/sec"
      summary_sheet.row(index).push key, requests_count, average_time, min_time, max_time, std_dev, error_rate,throughput, sent_kb_s, received_kb_s, aver_bytes
      summary_table.add_row [key, requests_count, average_time, min_time, max_time, std_dev, error_rate,throughput,sent_kb_s,received_kb_s, aver_bytes]
      index = index + 1
    end
    aver_bytes_total = aver_bytes_list.sum/aver_bytes_list.count
    received_kb_s_total = received_kb_s_list.sum.round(2)
    sent_kb_s_total = sent_kb_s_list.sum.round(2)
    total_average = (average_list.sum / average_list.size)
    min_time = min_list.min
    max_time = max_list.max
    std_dev = (std_list.sum / std_list.size)
    error_rate = (error_rate_list.sum / error_rate_list.size).round(2)
    throughput = (total_requests_count/duration_seconds.to_f).round(1).to_s + "/sec"
    summary_sheet.row(index).push "TOTAL", total_requests_count, total_average, min_time, max_time, std_dev, error_rate.to_s + "%",throughput,sent_kb_s_total, received_kb_s_total, aver_bytes_total
    summary_table.add_row(["TOTAL", total_requests_count, total_average, min_time, max_time, std_dev, error_rate.to_s + "%",throughput,sent_kb_s_total, received_kb_s_total, aver_bytes_total])
    FileUtils::mkdir_p "#{$my_root}../../awetest_report"
    book.write "#{$my_root}../../awetest_report/#{Time.now.to_s.gsub("-", "_").gsub(" ", "-").gsub(":","_")}.xls" rescue puts("ERROR: Failed to generate excel")
    html_string = create_html_report(summary_table, error_rate, chart_over_time, time_over_threads ,threads_over_time)
    File.open("#{$my_root}../../awetest_report/#{$test_suit.sheet_name}_#{Time.now.strftime "%d_%m_%H_%M_%S"}.html", 'w') {|file| file.write(html_string)}
  end
end
def exec_job(job_id, environment,test_suit,test_ids,num_of_threads,test_params_all,test_end_time, max_loops)
  threads = []
  #puts "Test begins for with #{num_of_threads} threads"

  (1..(num_of_threads)).each do |n|
    test_params_test = test_params_all.shift
    threads.push(Thread.new{
                   begin
                     run_test(test_suit, test_ids, n, num_of_threads, test_params_test, test_end_time, job_id, max_loops)
                   rescue => e
                     puts "ERROR: #{environment} job# #{job_id}, thread # #{n} failed"
                     puts "Stopping the teset as we have a thread that have failed"
                     $finish_now = true
                     puts e.to_s
                     puts e.backtrace
                   end
                 })
  end
  threads.each do |thread|
    thread.join
  end
  #thread_working = true
  # while thread_working
  #   thread_working =false
  #   threads= threads.select do |thread|
  #     result = thread.status
  #     if result
  #       thread_working = true
  #     else
  #       $lock.synchronize{
  #         $total_threads_num -=1
  #       }
  #       thread.join
  #     end
  #     result
  #   end
  #   sleep 0.002*$total_threads_num
  #   sleep 0.2 #unless $finish_now#check for thread cont every 200ms
  # end


end

def run_test( test_suit, test_ids, thread_num, num_of_threads, test_params, test_end_time, job_id, max_loops)

    run_id = 1
    run_id_padded = run_id.to_s.rjust(9, '0')
    start_time = Time.now
    until $finish_now
      if (max_loops != 0 && max_loops < run_id) || (test_end_time != 0 && test_end_time < Time.now)
        $finish_now = true
        next
      end
        total_threads_num = $total_threads_num
        test_run_time = []
        
        real_thread_num = thread_num + (job_id-1)*num_of_threads

        flow_result = true
        total_attempts = 0
        total_response_time = 0
        test_items = []

        test_ids.each_with_index do |test_id, test_number|
            $request_total_attempts.times {|attempt|
            api_test = test_suit.load_test(test_id,test_params,test_items)#
            set_current_test(api_test)
            api_test.run_test
            time = Time.now.getutc
            end_time = time
            overhead_time = ((end_time - start_time).to_f*1000).to_i - api_test.response_time
            start_time = time
            total_attempts = total_attempts + 1
            total_response_time += api_test.response_time
            bytes_sent = api_test.request_size
            if $log_all_requests || !api_test.no_errors
              $performance_report_steps["#{time.to_f}_#{real_thread_num}_#{run_id_padded}_#{test_number}_#{attempt}"] = time,$total_threads_num, real_thread_num,run_id, test_id,attempt+1, api_test.response_time,flow_result.to_s, api_test.no_errors.to_s,overhead_time, api_test.bytesize, bytes_sent, api_test.request_type,api_test.url, api_test.request_headers.to_s, api_test.request_body.to_s,api_test.expected_code.to_s, api_test.actual_body,api_test.actual_headers.to_s,api_test.actual_code.to_s, api_test.error, api_test.log.first($excel_cell_limit)
            else
              $performance_report_steps["#{time.to_f}_#{real_thread_num}_#{run_id_padded}_#{test_number}_#{attempt}"] = time,$total_threads_num, real_thread_num,run_id, test_id,attempt+1, api_test.response_time,flow_result.to_s, api_test.no_errors.to_s, overhead_time, api_test.bytesize, bytes_sent
            end
            unless api_test.no_errors
                 if attempt < ($request_total_attempts - 1)
                     flow_result = true
                     next
                 else
                     flow_result = false
                 end
            end
            test_run_time << api_test.response_time
                break
            }
        end
        time = Time.now.getutc
        aver_total_num_threads = ($total_threads_num+total_threads_num)/2
        throughput =  (aver_total_num_threads/((total_response_time/total_attempts)/1000.0)).round(1)
        $performance_report["#{time.to_f}_#{real_thread_num}_#{run_id_padded}}"] = time,$total_threads_num, real_thread_num,run_id, flow_result.to_s,throughput, *test_run_time
        run_id += 1
        run_id_padded = run_id.to_s.rjust(9, '0')
    end


end


def mean(a)
  a.sum/a.length.to_f
end

def sample_variance(a)
  m = mean(a)
  sum = a.inject(0){|accum, i| accum + (i-m)**2 }
  sum/(a.length - 1).to_f
end

def standard_deviation(a)
  return Math.sqrt(sample_variance(a))
end

def processor_count
  case RbConfig::CONFIG['host_os']
    when /darwin9/
      `hwprefs cpu_count`.to_i
    when /darwin/
      ((`which hwprefs` != '') ? `hwprefs thread_count` : `sysctl -n hw.ncpu`).to_i
    when /linux/
      `cat /proc/cpuinfo | grep processor | wc -l`.to_i
    when /freebsd/
      `sysctl -n hw.ncpu`.to_i
    when /mswin|mingw/
      require 'win32ole'
      wmi = WIN32OLE.connect("winmgmts://")
      cpu = wmi.ExecQuery("select NumberOfCores from Win32_Processor") # TODO count hyper-threaded in this
      cpu.to_enum.first.NumberOfCores
  end
end
#$available_cores = processor_count


def create_html_report(summary_table, error_rate, chart_over_time, time_over_threads, threads_over_time)
  report = get_html_report_string
  report = report.gsub('SUMMARY_TABLE', summary_table.to_html)
  report = report.gsub('ERROR_RATE', (100-error_rate).to_s)
  report =  report.gsub('CHART_OVER_TIME', chart_over_time.get_final)
  report =  report.gsub('THREADS_OVER_TIME', threads_over_time.get_final)
  report =  report.gsub('CHART_OVER_THREADS', time_over_threads.get_final)
 # report.gsub('CHART_OVER_THREADS', chart_over_threads.get_final_threads)
end

class SummaryTable
  attr_accessor :headers
  def initialize
    @headers = [ "Test ID","# Requests","Average", "Min", "Max", "Std. Dev", "Error %", "Avg. Throughput" ,"Sent KB/s","Recieved KB/s", "Average Bytes"]
    @rows = []
  end

  def add_row(row)
    @rows << row
  end

  def to_html
    html = "<table>"
    html << "<tr>"
    @headers.each do |header|
      html<< "<th>#{header}</th>"
    end
    html << "</tr>"
    @rows.each do |row|
      html << "<tr>"
      row.each do |row_item|
        html << "<td>#{row_item}</td>"
      end
      html << "</tr>"
    end
    html << "</table>"
    html
  end

end

def get_html_report_string
  %Q{
  <!DOCTYPE html>
<html lang="en">
<head>
<script src="https://code.jquery.com/jquery-3.1.1.min.js"></script>
    <script src="https://code.highcharts.com/highcharts.js"></script>
    <script src="https://code.highcharts.com/highcharts-more.js"></script>

    <script src="https://code.highcharts.com/modules/solid-gauge.js"></script>
<script src="https://code.highcharts.com/modules/exporting.js"></script>

    <style>
        table {
            font-family: arial, sans-serif;
            border-collapse: collapse;
            width: 100%;
        }

        td, th {
            border: 1px solid #dddddd;
            text-align: left;
            padding: 8px;
        }

        tr:nth-child(even) {
            background-color: #dddddd;
        }
        tr:last-child {
            background-color: #dddd88;
        }
    </style>
    <meta charset="UTF-8">
    <title></title>
</head>
<body>


<div style="width: 600px; height: 400px; margin: 0 auto">
    <div id="container-speed" style="width: 300px; height: 200px; float: left"></div>
</div>
SUMMARY_TABLE
<div id="all_over_time" style="min-width: 310px; height: 400px; margin: 0 auto"></div>
<div id="threads_over_time" style="min-width: 310px; height: 400px; margin: 0 auto"></div>
<div id="time_over_threads" style="min-width: 310px; height: 400px; margin: 0 auto"></div>
<script type="text/javascript">
    Highcharts.setOptions({
        global: {
            useUTC: false
        }
    });
    var gaugeOptions = {

        chart: {
            type: 'solidgauge'
        },

        title: null,

        pane: {
            center: ['50%', '85%'],
            size: '140%',
            startAngle: -90,
            endAngle: 90,
            background: {
                backgroundColor: (Highcharts.theme && Highcharts.theme.background2) || '#EEE',
                innerRadius: '60%',
                outerRadius: '100%',
                shape: 'arc'
            }
        },

        tooltip: {
            enabled: false
        },

        // the value axis
        yAxis: {
            stops: [
                [0.1, '#DF5353'], // green
                [0.5, '#DDDF0D'], // yellow
                [0.9, '#55BF3B'] // red
            ],
            lineWidth: 0,
            minorTickInterval: null,
            tickAmount: 2,
            title: {
                y: -70
            },
            labels: {
                y: 16
            }
        },

        plotOptions: {
            solidgauge: {
                dataLabels: {
                    y: 5,
                    borderWidth: 0,
                    useHTML: true
                }
            }
        }
    };

    // The speed gauge
    var chartSpeed = Highcharts.chart('container-speed', Highcharts.merge(gaugeOptions, {
        exporting: { enabled: false },
        yAxis: {
            min: 0,
            max: 100,
            title: {
                text: '% Tests Passed'
            }
        },

        credits: {
            enabled: false
        },

        series: [{
            name: 'Speed',
            data: [ERROR_RATE],
            dataLabels: {
                format: '<div style="text-align:center"><span style="font-size:25px;color:' +
                ((Highcharts.theme && Highcharts.theme.contrastTextColor) || 'black') + '">{y}</span><br/>' +
                '<span style="font-size:12px;color:silver">%</span></div>'
            },
            tooltip: {
                valueSuffix: '%'
            }
        }]

    }));
</script>
<script type="text/javascript">
CHART_OVER_TIME
</script>
<script type="text/javascript">
THREADS_OVER_TIME
</script>
<script type="text/javascript">
CHART_OVER_THREADS
</script>
</body>
</html>
}
end

class ChartClass

  def initialize(data,names, graph_type)
    @datas = data
    @series_string = ''
    @data_string = ''
    @names = names
    @graph_type = graph_type

  end



  def get_final()

    raw_chart = ''
   case @graph_type
     when 'all_over_time'
        raw_chart =  get_chart_all_over_time
     when 'threads_over_time'
        raw_chart = get_chart_threads_over_time
     when 'time_over_threads'
        raw_chart = get_chart_time_over_threads
   end

    string = raw_chart.gsub("SERIES_STRING", @series_string )
    string = string.gsub("GRAPH_TYPE", @graph_type)
    string.gsub("DATA_STRINGS", @data_string)
  end

def add_data_strings

  @datas.each_with_index do |data, index |
    index = index.to_s
    @data_string << "var data#{@graph_type}#{index} = #{data.to_json};\n"
  end

end
  def add_series()

    @series_string << "["

    first = true
    last = @names.count - 1
    last = -1 if @datas.count == 1
    @datas.each_with_index do |data, index|
      name = @names[index]


      @series_string << "," unless first
      first = false

      d = ''

        d ="yAxis: 1,\n lineWidth: 3," if last == index

      @series_string << %Q{
        {    name: '#{name}',
             #{d}
             data: data#{@graph_type}#{index}
           }
      }
    end

    @series_string << "]"

  end


def get_chart_all_over_time
  %Q{
  DATA_STRINGS
  Highcharts.chart('GRAPH_TYPE', {
    chart: {
        type: 'spline'
    },
    title: {
        text:'Response Time & Number of Threads Over Time'
    },
    subtitle: {
        text: ''
    },
    xAxis: {
          type: 'datetime',
          dateTimeLabelFormats: { // don't display the dummy year
          millisecond: '%S.%L'
        },
        title: {
            text: 'Time'
        }
    },
     yAxis: [{
                    title: {
                        text: "Response time ms"
                    },
                    minRange: 0.1
                },{
                    title: {
                        text: 'Number of Threads'
                    },
                    opposite: true,

                }],
     tooltip: {
                   formatter: function() {
                      var point;
                      var string = '';
                      var arrayLength =this.points.length;
                      for (var i = 0; i < arrayLength; i++) {
                          point = this.points[i];
                          string = string.concat('<div style="font-weight:bold; color: '+ point.series.color +'">' + point.series.name + '</div><br/>' + Highcharts.dateFormat('%I:%M:%S %P', this.x) + ' : ' + point.y + '<br/>');
                      }
                      return string
                  },
                  shared: true
              },

    plotOptions: {
        spline: {
            marker: {
                enabled: false
            }
        }
    },
    series: SERIES_STRING
})
}
end

  def get_chart_threads_over_time
    %Q{
  DATA_STRINGS
  Highcharts.chart('GRAPH_TYPE', {
    chart: {
        type: 'spline'
    },
    title: {
        text:'# Threads over time'
    },
    subtitle: {
        text: ''
    },
    xAxis: {
          type: 'datetime',
          dateTimeLabelFormats: { // don't display the dummy year
          millisecond: '%S.%L'
        },
        title: {
            text: 'Time'
        }
    },
     yAxis: {
                    title: {
                        text: 'Number of Threads'
                    }
                },
     tooltip: {
                   formatter: function() {
                      var point;
                      var string = '';
                      var arrayLength =this.points.length;
                      for (var i = 0; i < arrayLength; i++) {
                          point = this.points[i];
                          string = string.concat('<div style="font-weight:bold; color: '+ point.series.color +'">' + point.series.name + '</div><br/>' + Highcharts.dateFormat('%I:%M:%S %P', this.x) + ' : ' + point.y + '<br/>');
                      }
                      return string
                  },
                  shared: true
              },

    plotOptions: {
        spline: {
            marker: {
                enabled: false
            }
        }
    },
    series: SERIES_STRING
})
}
  end

  def get_chart_time_over_threads
    %Q{
  DATA_STRINGS
  Highcharts.chart('GRAPH_TYPE', {
    chart: {
        type: 'spline'
    },
    title: {
        text:'Response Time & Number of Threads Over Time'
    },
    subtitle: {
        text: ''
    },
    xAxis: {
           title: {
            text: 'Threads'
        }
    },
     yAxis: [{
                    title: {
                        text: "Response time ms"
                    },
                    minRange: 0.1
                },{
             title: {
                 text: 'Throughput r/s'
             },
             opposite: true,

     }],
     tooltip: {
                   formatter: function() {
                      var point;
                      var string = '';
                      var arrayLength =this.points.length;
                      for (var i = 0; i < arrayLength; i++) {
                          point = this.points[i];
                          string = string.concat('<div style="font-weight:bold; color: '+ point.series.color +'">' + point.series.name + '</div><br/>' + this.x + ' : ' + point.y + '<br/>');
                      }
                      return string
                  },
                  shared: true
              },

    plotOptions: {
        spline: {
            marker: {
                enabled: false
            }
        }
    },
    series: SERIES_STRING
})
}
  end

  def chart_string # chart with zoom
    %Q{
    DATA_STRINGS

    var detailChart;

        $(document).ready(function() {

            // create the detail chart
            function createDetail(masterChart) {

                // prepare the detail chart
                var detailDatas = [],
                DATA_START_POINTS

                var arrayLength = masterChart.series.length
                for (var i = 0; i < arrayLength; i++) {
                $.each(masterChart.series[i].data, function() {
                    if (this.x >= detailStart0) {
                        detailDatas[i] = (detailDatas[i] === undefined) ? [] : detailDatas[i];
                        detailDatas[i].push([this.x, this.y]);
                    }
                });};


                // create a detail chart referenced by a global variable
                detailChart = Highcharts.chart('detail-container', {
                    chart: {
                        marginBottom: 120,
                        reflow: false,
                        marginLeft: 100,
                        marginRight: 100,
                        style: {
                            position: 'absolute'
                        }
                    },
                    credits: {
                        enabled: false
                    },
                    title: {
                        text: 'Response Time & Number of Threads Over Time'
                    },
                    subtitle: {
                        text: 'Select an area by dragging across the lower chart'
                    },
                    xAxis: {
                        type: 'datetime',
                        dateTimeLabelFormats: {
                            millisecond: '%S.%L'
                        }
                    },
                    yAxis: [{
                        title: {
                            text: "Response time ms"
                        },
                        minRange: 0.1
                    },{
                        title: {
                            text: 'Number of Threads'
                        },
                        opposite: true,

                    }],
                    tooltip: {
                         formatter: function() {
                            var point;
                            var string = '';
                            var arrayLength =this.points.length;
                            for (var i = 0; i < arrayLength; i++) {
                                point = this.points[i];
                                string = string.concat('<div style="font-weight:bold; color: '+ point.series.color +'">' + point.series.name + '</div><br/>' + Highcharts.dateFormat('%I:%M:%S %P', this.x) + ' : ' + point.y + '<br/>');
                            }
                            return string
                        },
                        shared: true
                    },
                    legend: {
                        enabled: false
                    },
                    plotOptions: {
                        series: {
                            marker: {
                                enabled: false,
                                states: {
                                    hover: {
                                        enabled: true,
                                        radius: 3
                                    }
                                }
                            }
                        }
                    },
                    series: SERIES_2_STRING,

                    exporting: {
                        enabled: false
                    }

                }); // return chart
            }

            // create the master chart
            function createMaster() {
                Highcharts.chart('master-container', {
                    chart: {
                        reflow: false,
                        borderWidth: 0,
                        backgroundColor: null,
                        marginLeft: 50,
                        marginRight: 100,
                        zoomType: 'x',
                        events: {

                            // listen to the selection event on the master chart to update the
                            // extremes of the detail chart
                            selection: function(event) {
                                var extremesObject = event.xAxis[0],
                                        min = extremesObject.min,
                                        max = extremesObject.max,
                                        detailDatas = []
                                        xAxis = this.xAxis[0];

                                // reverse engineer the last part of the data
                                var arrayLength = this.series.length
                                for (var i = 0; i < arrayLength; i++) {
                                $.each(this.series[i].data, function() {
                                    if (this.x > min && this.x < max) {
                                        detailDatas[i] = (detailDatas[i] === undefined) ? [] : detailDatas[i];
                                        detailDatas[i].push([this.x, this.y]);
                                    }
                                });
                                };


                                // move the plot bands to reflect the new detail span
                                xAxis.removePlotBand('mask-before');
                                xAxis.addPlotBand({
                                    id: 'mask-before',
                                    from: data0[0][0],
                                    to: min,
                                    color: 'rgba(0, 0, 0, 0.2)'
                                });

                                xAxis.removePlotBand('mask-after');
                                xAxis.addPlotBand({
                                    id: 'mask-after',
                                    from: max,
                                    to: TO_DATARANGE,
                                    color: 'rgba(0, 0, 0, 0.2)'
                                });

                                var arrayLength = detailChart.series.length
                                for (var i = 0; i < arrayLength; i++) {
                                    detailChart.series[i].setData(detailDatas[i]);
                                };
                                return false;
                            }
                        }
                    },
                    title: {
                        text: null
                    },
                    xAxis: {
                        type: 'datetime',
                        showLastTickLabel: true,
                        minRange: MAX_ZOOM_MS,
                        plotBands: [{
                            id: 'mask-before',
                            from: data0[0][0],
                            to: TO_DATARANGE,
                            color: 'rgba(0, 0, 0, 0.2)'
                        }],
                        title: {
                            text: null
                        }
                    },
                    yAxis: [{
                        gridLineWidth: 0,
                        labels: {
                            enabled: false
                        },

                        title: {
                            text: null
                        },
                        min: 0.6,
                        showFirstLabel: false
                    },{
                        opposite: true,
                        gridLineWidth: 0,
                        title: {
                            text: null
                        },
                        labels: {
                            enabled: false
                        },
                        min: 0.6,
                        showFirstLabel: false

                    }],
                    tooltip: {
                        formatter: function() {
                            return false;
                        }
                    },
                    legend: {
                        enabled: false
                    },
                    credits: {
                        enabled: false
                    },
                    plotOptions: {
                        series: {
                            fillColor: {
                                linearGradient: [0, 0, 0, 70],
                                stops: [
                                    [0, Highcharts.getOptions().colors[0]],
                                    [1, 'rgba(255,255,255,0)']
                                ]
                            },
                            lineWidth: 1,
                            marker: {
                                enabled: false
                            },
                            shadow: false,
                            states: {
                                hover: {
                                    lineWidth: 1
                                }
                            },
                            enableMouseTracking: false
                        }
                    },

                    series: SERIES_STRING,


                    exporting: {
                        enabled: false
                    }

                }, function(masterChart) {
                    createDetail(masterChart);
                }); // return chart instance
            }

            // make the container smaller and add a second container for the master chart
            var $container = $('#all_over_time')
                    .css('position', 'relative');

            $('<div id="detail-container">')
                    .appendTo($container);

            $('<div id="master-container">')
                    .css({
                        position: 'absolute',
                        top: 300,
                        height: 100,
                        width: '100%'
                    })
                    .appendTo($container);

            // create master and in its callback, create the detail chart
            createMaster();
        });
}
  end
end