module ConferenceSessions
  class FavoritesController < ApplicationController
    before_action :set_conference_session

    def create
      Current.user.favorites.find_or_create_by!(conference_session: @conference_session)
      redirect_to root_path, notice: "Session favorited."
    end

    def destroy
      Current.user.favorites.where(conference_session: @conference_session).destroy_all
      redirect_to root_path, status: :see_other, notice: "Session unfavorited."
    end

    private
      def set_conference_session
        @conference_session = ConferenceSession.find(params[:conference_session_id])
      end
  end
end
