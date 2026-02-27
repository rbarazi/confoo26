require "application_system_test_case"

class AuthenticationTest < ApplicationSystemTestCase
  test "user signs in and signs out" do
    user = users(:one)

    visit root_path
    assert_text "Sign in"

    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"

    assert_text "Welcome"
    assert_text user.email_address

    click_button "Sign out"

    assert_text "Sign in"
  end
end
