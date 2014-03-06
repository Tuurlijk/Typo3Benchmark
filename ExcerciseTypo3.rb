#!/usr/bin/ruby
#
# Excercise TYPO3 v 0.0.1
# Excercise TYPO3 backend and frontend
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

class ExcerciseTypo3 < Test::Unit::TestCase

	def setup
		@revision = ARGV[0] || raise("Please provide revision number as first argument")
		@baseUrl  = ARGV[1] || raise("Please provide a base url as second argument")
		@password = ARGV[2] || raise("Please provide TYPO3 backend password as second argument")

		profile = Selenium::WebDriver::Firefox::Profile.new
		profile['browser.cache.disk.enable'] = false
		profile['browser.cache.memory.enable'] = false
		profile['browser.cache.offline.enable'] = false
		profile['network.http.use-cache'] = false

		@browser = Selenium::WebDriver.for :firefox, :profile => profile

		# This cookie setting seems not to work for me, hence th _profile=1 below
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

	def test_excercise_typo3_backend
		# Warm the cache
		@browser.get(@baseUrl + "typo3/?" + @parameters)
		sleep 2
		@browser.get(@baseUrl + "typo3/?" + @parameters)
		verify { assert_match /Login to the TYPO3 Backend/, @browser.find_element(:id, "t3-login-form-inner").text }
		@browser.find_element(:id, "t3-username").clear
		@browser.find_element(:id, "t3-username").send_keys "admin"
		@browser.find_element(:id, "t3-password").clear
		@browser.find_element(:id, "t3-password").send_keys @password
		@browser.find_element(:id, "t3-login-submit").click
		@browser.get(@baseUrl + "typo3/backend.php?" + @parameters)
		sleep 2
		# Clear cache, now done in the shell script
		#@browser.find_element(:class, "t3-icon-toolbar-menu-cache").click
		#@browser.find_element(:css, "ul.toolbar-item-menu > li > a").click
		#sleep 2
		@browser.get(@baseUrl + "typo3/backend.php?" + @parameters)
		sleep 2
		@browser.get(@baseUrl + "typo3/sysext/cms/layout/db_layout.php?" + @parameters)
		sleep 1
		@browser.get(@baseUrl + "typo3/sysext/cms/layout/db_layout.php?id=6&" + @parameters)
		sleep 1
		@browser.get(@baseUrl + "typo3/mod.php?M=web_list&id=0&" + @parameters)
		sleep 1
		@browser.get(@baseUrl + "typo3/sysext/tstemplate/ts/index.php?&id=1&SET[ts_browser_type]=setup&" + @parameters)
		sleep 1
		@browser.get(@baseUrl + "typo3/sysext/filelist/mod1/file_list.php?id=%2Fwwwtest%2FTypo3Workbench%2FTargets%2FWebRoot%2F4.5.branch.workbench.typofree.org%2Ffileadmin%2Fdefault%2Ftemplates%2F&" + @parameters)
		sleep 1
		@browser.get(@baseUrl + "typo3/mod.php?M=tools_em&" + @parameters)
		sleep 1
		@browser.get(@baseUrl + "typo3/mod.php?M=tools_log&" + @parameters)
		sleep 1
		@browser.get(@baseUrl + "typo3/mod.php?&id=0&M=tools_txreportsM1&SET[function]=tx_reports.status&" + @parameters)
	end

	def test_excercise_typo3_frontend
		@browser.get(@baseUrl + "?" + @parameters)
		sleep 1
		@browser.get(@baseUrl + "examples/languages-characters/?" + @parameters)
		sleep 1
		@browser.get(@baseUrl + "examples/text-and-images/?" + @parameters)
		sleep 1
		@browser.get(@baseUrl + "examples/images-with-links/?" + @parameters)
		sleep 1
		@browser.get(@baseUrl + "examples/image-groups/?" + @parameters)
		sleep 1
		@browser.get(@baseUrl + "examples/tables/?" + @parameters)
		sleep 1
		@browser.get(@baseUrl + "examples/frames/?" + @parameters)
		sleep 1
		@browser.get(@baseUrl + "examples/file-downloads/?" + @parameters)
		sleep 1
		@browser.get(@baseUrl + "examples/site-map/?" + @parameters)
		sleep 1
	end

	def element_present?(how, what)
		@browser.find_element(how, what)
		true
	rescue Selenium::WebDriver::Error::NoSuchElementError
		false
	end

	def alert_present?()
		@browser.switch_to.alert
		true
	rescue Selenium::WebDriver::Error::NoAlertPresentError
		false
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