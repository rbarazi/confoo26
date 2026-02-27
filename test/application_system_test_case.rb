require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  Capybara.server_host = "0.0.0.0"
  Capybara.server_port = 40_001
  Capybara.app_host = "http://rails-app:#{Capybara.server_port}"

  driven_by :selenium, using: :chrome, screen_size: [ 1400, 1400 ], options: {
    browser: :remote,
    url: ENV.fetch("SELENIUM_DRIVER_URL", "http://chrome:4444")
  }
end
