#!/usr/bin/ruby
#
# Exercise TYPO3 v 0.0.1
# Exercise TYPO3 backend and frontend
#
# Copyright ⓒ 2014, Michiel Roos <michiel@maxserv.nl>
#
# Distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU General Public License for more details:
# http://www.gnu.org/licenses/gpl.txt

require "json"
require "selenium-webdriver"
gem "test-unit"
require "test/unit"

class ExerciseTypo3 < Test::Unit::TestCase

	def setup
		@revision = ARGV[0] || raise("Please provide revision number as first argument")
		baseUrl = ARGV[1] || raise("Please provide a base url as second argument")
		@baseUrl = baseUrl.gsub(/\/+$/, '')
		@password = ARGV[2] || raise("Please provide TYPO3 backend password as third argument")

		profile = Selenium::WebDriver::Firefox::Profile.new
		profile['browser.cache.disk.enable'] = false
		profile['browser.cache.memory.enable'] = false
		profile['browser.cache.offline.enable'] = false
		profile['network.http.use-cache'] = false

		@browser = Selenium::WebDriver.for :firefox, :profile => profile

		# This cookie setting seems not to work for me, hence the _profile=1 below
		#@browser.manage.add_cookie(:name => "XHProf_Profile", :value => 1)
		@parameters = "gitRevision=" + @revision + "&_profile=1"

		@accept_next_alert = true
		@browser.manage.timeouts.implicit_wait = 30
		@verification_errors = []
	end

	def teardown
		@browser.quit
		assert_equal [], @verification_errors
	end

	def test_exercise_typo3_backend
		# Warm the cache
		@browser.get(@baseUrl + "/typo3/?" + @parameters)
		sleep 2

		# Login
		@browser.get(@baseUrl + "/typo3/?" + @parameters)
		verify { assert_match /Login to the TYPO3 Backend/, @browser.find_element(:id, "t3-login-form-inner").text }
		@browser.find_element(:id, "t3-username").clear
		@browser.find_element(:id, "t3-username").send_keys "admin"
		@browser.find_element(:id, "t3-password").clear
		@browser.find_element(:id, "t3-password").send_keys @password
		@browser.find_element(:id, "t3-login-submit").click

		getRequestsFromFile('backendRequests.txt')
	end

	def test_exercise_typo3_frontend
		getRequestsFromFile('frontendRequests.txt')
	end

	def getRequestsFromFile(file, sleepSeconds = 1)
		fh = File.new(file, 'r')
		while (line = fh.gets)
			# skip empty lines
			next if line.strip.empty?
			line.strip!
			# skip comments
			next if line =~ /\#.*/
			@browser.get(@baseUrl + line + (line =~ /\?.*/ ? '&' : '?' ) + @parameters)
			sleep sleepSeconds
		end
	end

	def verify(&blk)
		yield
	rescue Test::Unit::AssertionFailedError => ex
		@verification_errors << ex
	end

	def close_alert_and_get_its_text(how, what)
		alert = @browser.switch_to().alert()
		alert_text = alert.text
		if (@accept_next_alert) then
		alert.accept()
		else
		alert.dismiss()
		end
		alert_text
	ensure
		@accept_next_alert = true
	end
end