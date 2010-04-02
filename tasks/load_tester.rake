namespace :load_tester do
  
  require 'logger'
  
  desc 'Measures test coverage using rcov'
  task :test => :environment do
    STDOUT.sync = true # activate auto-flush
    puts "Starting load tests in #{Rails.env.upcase} environment"
    load_test = LoadTester.new("#{RAILS_ROOT}/config/load_tester.yml")
    load_test.config.each do |test|
      puts '-' * 50
      puts test[:name]
      puts '-' * 50

      test.each{|k, v| puts '%12s'%"#{k}" + ": #{v}"}
      puts '-' * 50

      load_test.run(test)

    end

    # Save html
    load_test.save_results
    puts 'Bye!'
  end
end
