require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "has favorited sessions through favorites" do
    user = users(:one)

    assert_includes user.favorited_sessions, conference_sessions(:legacy_code)
  end
end
