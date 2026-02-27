require "test_helper"

class FavoriteTest < ActiveSupport::TestCase
  test "valid with required attributes" do
    favorite = favorites(:one_legacy)
    assert favorite.valid?
  end

  test "enforces one favorite per user per session" do
    duplicate = Favorite.new(user: users(:one), conference_session: conference_sessions(:legacy_code))

    assert_not duplicate.valid?
    assert duplicate.errors[:conference_session_id].any?
  end

  test "belongs to user and conference_session" do
    favorite = favorites(:one_legacy)

    assert_equal users(:one), favorite.user
    assert_equal conference_sessions(:legacy_code), favorite.conference_session
  end
end
