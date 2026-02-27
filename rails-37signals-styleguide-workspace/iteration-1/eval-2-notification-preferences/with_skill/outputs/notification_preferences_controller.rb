# app/controllers/notification_preferences_controller.rb
#
# Thin controller — delegates to rich model methods.
# Each preference is updated individually via PATCH, returning a Turbo Stream
# so the page updates without a full reload.
#
# Routes:
#   resources :notification_preferences, only: [:index, :update]

class NotificationPreferencesController < ApplicationController
  before_action :set_notification_preference, only: :update

  def index
    @notification_preferences = Current.user.notification_preferences_for_all_events
  end

  def update
    @notification_preference.update!(notification_preference_params)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to notification_preferences_path, notice: "Preference updated." }
    end
  end

  private

  def set_notification_preference
    @notification_preference = Current.user.notification_preferences.find(params[:id])
  end

  def notification_preference_params
    params.expect(notification_preference: [ :email_enabled ])
  end
end
