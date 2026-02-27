class Favorite < ApplicationRecord
  belongs_to :user
  belongs_to :conference_session

  validates :conference_session_id, uniqueness: { scope: :user_id }
end
