class ScheduleEntry < ApplicationRecord
  belongs_to :conference_session, inverse_of: :schedule_entry
  has_one :speaker, through: :conference_session

  validates :day, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true
  validates :room, presence: true

  scope :on_day, ->(date) { where(day: date) }
  scope :in_room, ->(room) { where(room: room) }
  scope :chronological, -> { order(:day, :start_time) }

  DAY_DATES = {
    "Wednesday" => Date.new(2026, 2, 25),
    "Thursday"  => Date.new(2026, 2, 26),
    "Friday"    => Date.new(2026, 2, 27)
  }.freeze

  def day_name
    day.strftime("%A")
  end

  def time_range
    "#{start_time.strftime('%H:%M')}-#{end_time.strftime('%H:%M')}"
  end
end
