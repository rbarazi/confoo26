# test/mailers/weekly_digest_mailer_test.rb
require "test_helper"

class WeeklyDigestMailerTest < ActionMailer::TestCase
  test "digest email is addressed to the user" do
    user = users(:one)

    email = WeeklyDigestMailer.digest(user)

    assert_equal [ user.email ], email.to
    assert_includes email.subject, user.account.name
  end

  test "digest email renders both text and html parts" do
    user = users(:one)

    email = WeeklyDigestMailer.digest(user)

    assert_match "weekly digest", email.html_part.body.to_s.downcase
    assert_match "weekly digest", email.text_part.body.to_s.downcase
  end
end
