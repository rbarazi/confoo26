class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :favorites, dependent: :destroy
  has_many :favorited_sessions, through: :favorites, source: :conference_session

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
