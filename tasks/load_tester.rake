namespace :load_tester do
  
  require 'logger'
  
  desc 'Measures test coverage using rcov'
  task :test => :environment do
    STDOUT.sync = true # activate auto-flush
    puts "Starting load tests in #{Rails.env.upcase} environment"
    if !File.exists?(RAILS_ROOT+'/config/load_test.yml')
      puts "ERROR: Couldn't find #{RAILS_ROOT}/config/load_test.yml"
    else
      logger = Logger.new(File.join(RAILS_ROOT, 'log', "load_test_#{RAILS_ENV}.log"))
      dst_folder = File.join(RAILS_ROOT, 'tmp', 'load_test')
      FileUtils.mkdir_p(dst_folder)
      html_output = HtmlOutput.new
      
      load_test_config = YAML::load(File.open(RAILS_ROOT+'/config/load_test.yml'))
      load_test_config.each do |test|
        puts '-' * 50
        puts test[0]
        puts '-' * 50
        html_output.add_test_header(test)

        # Collect the parameters for the test
        params = {}
        test[1].each{|k,v| params[k.to_sym] = v}
        params[:file] = File.join(dst_folder, params[:file])
        params.each{|k, v| puts '%12s'%"#{k}" + ": #{v}"}
        puts '-' * 50
        
        # Run the tests
        command =  "autobench #{params.collect{|k, v| "--#{k} #{v}"}.join(' ')}"
        puts command
        logger.info '=' * 50 + 'Started test on ' + Time.now.to_s
        logger.info %x[#{command}]

        # Collect result data
        print 'Generating charts...'
        html_output.parse_result(params[:file])
        puts 'Done'
      end
    end
    # Save html
    html_output.save_to(File.join(dst_folder, "index.html"))
    puts 'Bye!'
  end
end
