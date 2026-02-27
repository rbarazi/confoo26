require "test_helper"

class ConferenceSessions::FavoritesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @conference_session = conference_sessions(:agentic_ai)

    sign_in_as(@user)
  end

  test "create favorites session for current user" do
    assert_difference("Favorite.count", 1) do
      post conference_session_favorite_path(@conference_session)
    end

    assert_redirected_to root_path
    assert Favorite.exists?(user: @user, conference_session: @conference_session)
  end

  test "create is idempotent when already favorited" do
    favorite = favorites(:one_legacy)

    assert_no_difference("Favorite.count") do
      post conference_session_favorite_path(favorite.conference_session)
    end

    assert_redirected_to root_path
  end

  test "destroy removes favorite for current user only" do
    favorites(:two_agentic)
    @user.favorites.create!(conference_session: @conference_session)

    assert_difference("Favorite.count", -1) do
      delete conference_session_favorite_path(@conference_session)
    end

    assert_redirected_to root_path
    assert_not Favorite.exists?(user: @user, conference_session: @conference_session)
    assert Favorite.exists?(user: users(:two), conference_session: @conference_session)
  end
end
