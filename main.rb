#!/usr/bin/env ruby

# This is a command-line utility for the bulk-downloading of run data from
# the mapmyrun.com web application. You can not "bulk" download run/workout data
# without a paid account, so this script gets around that.
#
# The script mimics "drives" a web browser (Google Chrome) around the site just as you would
# manually and collects the data.
#
# The script was created around September 2016. It's fragile and likely to break at some time in the
# future when mapmyrun.com changes.
#
# This script requires all of the utilities on the line below: install them
# with rubygems. Google Chrome is also required.
%w{rubygems json fileutils choice watir active_support/all watir-webdriver watir-webdriver/wait}.map{|x| require x }

# Also required: chromedriver. This script tested with the chromedriver file in this repository (built for the mac).
# Other chromedriver downloads: https://sites.google.com/a/chromium.org/chromedriver/downloads

# Example use
# ruby main.rb -u <your username/email> -o /Users/<you>/Downloads/runs -p <enter your password here>

LOGIN_PAGE = "https://www.mapmyrun.com/auth/login/"
ACTIVITIES_SEARCH = "http://www.mapmyrun.com/workouts/"

Choice.options do
  header ''
  header 'Specific options:'

  option :user, :required => true do
    short '-u'
    long '--user=USER'
    desc 'mapmyrun.com username. Required'
  end

  option :pass, :required => true do
    short '-p'
    long '--pass=PASS'
  end

  option :dir do
    short '-o'
    long '--output-dir=OUTPUT'
    desc 'the directory to save .tcx files'
    default 'tcx'
  end
end

#Expects that chromedriver is sitting beside this ruby script in the file folder
chromedriver_path = File.join(File.dirname(__FILE__), "chromedriver")
Selenium::WebDriver::Chrome.driver_path = chromedriver_path

#Sets up the chrome browser to download files to the directory the user specifies.
prefs = {
    :download => {
        :prompt_for_download => false,
        :default_directory => Choice[:dir]
    }
}
browser = Watir::Browser.new :chrome, :prefs => prefs

# Login
browser.goto LOGIN_PAGE
browser.text_field(name: 'email').set Choice[:user]
browser.text_field(name: 'password').set Choice[:pass]
browser.button(id: 'submit').click

# Wait until the welcome screen/dashboard loads
browser.element(:css => '.my_status__text').wait_until_present(timeout = 60)

still_getting_data = true
start_year = Time.now
workouts = []
# Start from the current month and work backwards. The script will stop collecting data when it encounters
# a month with no activity.
while still_getting_data
  still_getting_data = false
  puts "Getting: #{start_year.month} - #{start_year.year}"

  # Downloads JSON data for the month
  browser.goto "http://www.mapmyrun.com/workouts/dashboard.json?month=#{start_year.month}&year=#{start_year.year}"

  # Wait until the JSON data loads into the browser
  browser.element(:css => "pre").wait_until_present

  # Parse JSON as a ruby object
  json = JSON.parse(browser.element(:css => "pre").inner_html)
  json['workout_data']['workouts'].each { |wo|
    workouts << wo[1][0]['view_url']
    still_getting_data = true
  }
  start_year -= 1.month
  workouts = workouts.uniq
  puts "Found #{workouts.length} runs to download."
end

puts workouts
#workouts is an array of links. Remove part of the path to leave only the workout ID.
#Example: '/workout/123456789'
workouts = workouts.map { |w|
  w[9..-1]
}

# Create the directory the user chose if it doesn't exist.
FileUtils.mkdir_p(Choice[:dir]) if not File.directory?(Choice[:dir])
puts "Downloading runs..."
workouts.each { |w|
  path = "http://www.mapmyrun.com/workout/export/#{w}/tcx"
  puts path
  browser.goto path
}

#Hack to keep the script/browser running to continue downloading the last file
while Dir[Choice[:dir]].glob('*.crdownload').any?
  sleep 0.1
end

puts "Finished. Workouts downloaded to #{Choice[:dir]}"


