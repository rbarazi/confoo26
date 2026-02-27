require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  if ENV["SELENIUM_DRIVER_URL"].present?
    Capybara.server_host = "0.0.0.0"
    Capybara.server_port = 40_001
    Capybara.app_host = ENV.fetch("CAPYBARA_APP_HOST", "http://rails-app:#{Capybara.server_port}")

    driven_by :selenium, using: :chrome, screen_size: [ 1400, 1400 ], options: {
      browser: :remote,
      url: ENV.fetch("SELENIUM_DRIVER_URL")
    }
  else
    driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]
  end
end
