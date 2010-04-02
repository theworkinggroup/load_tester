class LoadTester
  attr_accessor :html_output, 
                :logger, 
                :dst_folder,
                :config

  OUTPUT_FOLDER = File.join(RAILS_ROOT, 'tmp', 'load_test')


  def initialize(config_file)
    if !File.exists?(config_file)
      raise "ERROR: Couldn't find #{config_file}"
    else
      self.html_output  = ''
      self.config       = []
      self.logger       = Logger.new(File.join(RAILS_ROOT, 'log', "load_test_#{RAILS_ENV}.log"))
      load_configuration(YAML::load(File.open(config_file)))
      FileUtils.mkdir_p(OUTPUT_FOLDER)
    end
  end
  
  def run(test)
    params = test.collect do |k, v|
      next if k == :name
      if k == :single_host && v == true
        "--single_host"
      else
        "--#{k} #{v}"
      end
    end
    command =  "autobench #{params.join(' ')}"
    puts command
    self.log '=' * 50 + 'Started test on ' + Time.now.to_s
    self.log %x[#{command}]
    
    # Collect result data
    print 'Generating charts...'
    parse_result(test[:file])
    puts 'Done'
  end
  
  def log(data)
    self.logger.info data
  end

  
  def save_results
    open(File.join(OUTPUT_FOLDER, "index.html"), 'w') do |f|
      f.write(%{
        <?xml version='1.0' encoding='utf-8' ?>
        <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
        <html xml:lang='en' xmlns='http://www.w3.org/1999/xhtml'>
        <head>
          <script src="jquery.js" type="text/javascript"></script>
          <script src="jquery.jqplot.min.js" type="text/javascript"></script>
          <script type="text/javascript" src="jqplot.canvasTextRenderer.min.js"></script>
          <script type="text/javascript" src="jqplot.canvasAxisLabelRenderer.min.js"></script>
          <script type="text/javascript" src="jqplot.highlighter.min.js"></script>
          <link rel="stylesheet" type="text/css" href="jquery.jqplot.min.css" />
          <link rel="stylesheet" type="text/css" href="style.css" />
        </head>
        <body>
          <div class="wrapper">
            <div class="header"><h1>Load test results</h1></div>
            <div class="content">#{self.html_output}</div>
            <div class="footer">
              <div class="copyright">&copy; 2010 <a href="http://twg.ca" target="_blank">The Working Group, Inc</a></div>
            </div>
          </div>
        </body>
        </html>
      })
    end
    # Copy javascript files
    %w{jquery.js jquery.jqplot.min.js jqplot.canvasTextRenderer.min.js jqplot.canvasAxisLabelRenderer.min.js jqplot.highlighter.min.js jquery.jqplot.min.css style.css}.each do |script|
      FileUtils.cp("#{File.dirname(__FILE__)}/../javascripts/#{script}", OUTPUT_FOLDER)
    end
  end
  
  
protected

  def load_configuration(tests)
    tests.each do |test|
      params = {
        :name => test[0],
        :file => File.join(OUTPUT_FOLDER, 'results.tsv')
      }
      test[1].each{|k,v| params[k.to_sym] = v}
      self.config << params
      self.add_test_header(params)
    end
  end
  
  
  def add_test_header(test)
    self.html_output << %{
      <div class="test">
        <h1>#{test[:name]}<br/><span>#{test[:host1]+test[:uri1]}</span></h1>
        <p>
          Ran a series of tests each doing #{test[:num_conn]} connections with  #{test[:num_call]} request per connection and a #{test[:timeout]} second client timeout.
          <br/>The first with #{test[:low_rate]} conn/sec (#{test[:low_rate]*test[:num_call]} req/sec), the next with #{test[:rate_step]} more req/sec (#{test[:high_rate]*test[:num_call]} req/sec) until it reached #{test[:high_rate]} req/second
        </p>
        <table class="test_details">
          <tr><td colspan="2"><strong>TEST PARAMETERS</strong></td></tr>
          <tr><td>url</td>      <th>#{test[:host1]+test[:uri1]}</th></tr>
          <tr><td>port</td>     <th>#{test[:port1]}</th></tr>
          <tr><td>num_conn</td> <th>#{test[:num_conn]} req</th></tr>
          <tr><td>num_call</td> <th>#{test[:num_call]} conn/req</th></tr>
          <tr><td>timeout</td>  <th>#{test[:timeout]} sec</th></tr>
          <tr><td>low_rate</td> <th>#{test[:low_rate]} conn/sec (#{test[:low_rate]*test[:num_call]} req/sec)</th></tr>
          <tr><td>high_rate</td><th>#{test[:high_rate]} conn/sec (#{test[:high_rate]*test[:num_call]} req/sec)</th></tr>
          <tr><td>rate_step</td><th>#{test[:rate_step]}</th></tr>
        </table>
    }
  end
  
  
  def parse_result(result_file)
    attempted_request_rate = []
    average_reply_rate     = []
    average_response_time  = []
    errors                 = []
    File.open(result_file).each do |line|
      row = line.split("\t") 
      next if row[0] =~ /^\D+/
      attempted_request_rate  << row[0].to_f
      average_reply_rate      << row[4].to_f
      average_response_time   << row[7].to_f
      errors                  << row[9].to_f
    end
    charts = [
      {
        :title => 'Average reply rate (responses per second)',
        :data => [[],[],[],[]]
      }
    ]
    attempted_request_rate.each_index do |i|
      charts[0][:data][0] << [attempted_request_rate[i], attempted_request_rate[i]]
      charts[0][:data][1] << [attempted_request_rate[i], average_reply_rate[i]]
      charts[0][:data][2] << [attempted_request_rate[i], errors[i]]
      charts[0][:data][3] << [attempted_request_rate[i], average_response_time[i]]
    end
    add_chart(charts[0][:data], %{
      seriesColors: [ "#eeeeee", "#4bb2c5", "#57B24F", "#F9A52B"],
      legend:{show:true, location:'se'},
      axes: {
        xaxis: {
          label       : 'Requests per second',
          min         : #{charts[0][:data][0][0][0]},
          ticks       : #{charts[0][:data][0].collect{|d| d[0]}.to_json},
          tickOptions : { formatString: '%d' }
        },
        yaxis: {
          label         : 'Average responses per second',
          labelRenderer : $.jqplot.CanvasAxisLabelRenderer,
          min: 0,
          tickOptions   : { formatString: '%d' }
        },
        y2axis: {
          label         : 'Average response time (ms)',
          min           : 0,
          labelRenderer : $.jqplot.CanvasAxisLabelRenderer
        }
      },
      series: [
        { label: 'Request rate', fill: true, fillAlpha: 0.5 },
        { label: 'Average responses per second' },
        { label: 'Errors' },
        { label: 'Average response time (ms)', yaxis: 'y2axis' }
      ]
    })
    
  end
  
  
  def add_chart(data, params)
    chart_id = "#{(data+[rand(1000)]).hash}_#{self.id}"
    params << %{,
      highlighter: {
        tooltipAxes          : 'y',
        tooltipFormatString  : '%.1f seconds'
      }
    }
    self.html_output << %{
        <div class="chart" id="#{chart_id}" style="width:600px;height:300px;"></div>
        <script language="javascript" type="text/javascript">
          $(document).ready(function () {
            $.jqplot('#{chart_id}', #{data.to_json}, {#{params}});
          });
        </script>
      </div>
    }
  end
  
end