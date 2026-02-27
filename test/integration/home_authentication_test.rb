require "test_helper"

class HomeAuthenticationTest < ActionDispatch::IntegrationTest
  test "redirects guests to sign in" do
    get root_path

    assert_redirected_to new_session_path
  end

  test "shows home for signed in users" do
    sign_in_as(users(:one))

    get root_path

    assert_response :success
    assert_match("Welcome", response.body)
    assert_match(users(:one).email_address, response.body)
  end
end
