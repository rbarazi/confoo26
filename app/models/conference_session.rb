class ConferenceSession < ApplicationRecord
  belongs_to :speaker
  has_one :schedule_entry, dependent: :destroy, inverse_of: :conference_session
  has_many :favorites, dependent: :destroy
  has_many :favoriting_users, through: :favorites, source: :user

  validates :title, presence: true
  validates :description, presence: true
  validates :slug, presence: true, uniqueness: true

  scope :tagged, ->(tag) { where("tags @> ARRAY[?]::varchar[]", tag) }
  scope :scheduled, -> { joins(:schedule_entry) }
  scope :unscheduled, -> { left_joins(:schedule_entry).where(schedule_entries: { id: nil }) }
  scope :preloaded, -> { includes(:speaker, :schedule_entry) }

  before_validation :generate_slug, on: :create

  private
    def generate_slug
      self.slug ||= title&.parameterize
    end
end
