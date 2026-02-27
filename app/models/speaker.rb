class Speaker < ApplicationRecord
  has_many :conference_sessions, dependent: :restrict_with_error
  has_one_attached :photo

  validates :name, presence: true, uniqueness: true
  validates :bio, presence: true

  normalizes :name, with: ->(v) { v.strip }
end
