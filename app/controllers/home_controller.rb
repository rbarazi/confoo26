class HomeController < ApplicationController
  def show
    @conference_sessions = ConferenceSession.preloaded.order(:title)
    @favorite_session_ids = Current.user.favorites.where(conference_session: @conference_sessions).pluck(:conference_session_id).to_set
  end
end
