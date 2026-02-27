require "test_helper"

class ScheduleEntryTest < ActiveSupport::TestCase
  test "valid with required attributes" do
    entry = schedule_entries(:wednesday_legacy)
    assert entry.valid?
  end

  test "invalid without day" do
    entry = ScheduleEntry.new(start_time: "09:00", end_time: "10:00", room: "Room 1", conference_session: conference_sessions(:unscheduled))
    assert_not entry.valid?
    assert entry.errors[:day].any?
  end

  test "invalid without room" do
    entry = ScheduleEntry.new(day: Date.new(2026, 2, 25), start_time: "09:00", end_time: "10:00", conference_session: conference_sessions(:unscheduled))
    assert_not entry.valid?
    assert entry.errors[:room].any?
  end

  test "belongs to conference session" do
    entry = schedule_entries(:wednesday_legacy)
    assert_equal conference_sessions(:legacy_code), entry.conference_session
  end

  test "has one speaker through conference session" do
    entry = schedule_entries(:wednesday_legacy)
    assert_equal speakers(:anna), entry.speaker
  end

  test "on_day scope filters by date" do
    wednesday = ScheduleEntry.on_day(Date.new(2026, 2, 25))
    assert_includes wednesday, schedule_entries(:wednesday_legacy)
    assert_not_includes wednesday, schedule_entries(:thursday_ai)
  end

  test "in_room scope filters by room" do
    results = ScheduleEntry.in_room("ST-Laurent 5")
    assert_includes results, schedule_entries(:wednesday_legacy)
    assert_not_includes results, schedule_entries(:thursday_ai)
  end

  test "chronological scope orders by day and start_time" do
    entries = ScheduleEntry.chronological
    assert_equal schedule_entries(:wednesday_legacy), entries.first
    assert_equal schedule_entries(:thursday_ai), entries.last
  end

  test "day_name returns day of week" do
    entry = schedule_entries(:wednesday_legacy)
    assert_equal "Wednesday", entry.day_name
  end

  test "time_range formats start and end times" do
    entry = schedule_entries(:wednesday_legacy)
    assert_equal "09:00-10:30", entry.time_range
  end

  test "DAY_DATES maps day names to conference dates" do
    assert_equal Date.new(2026, 2, 25), ScheduleEntry::DAY_DATES["Wednesday"]
    assert_equal Date.new(2026, 2, 26), ScheduleEntry::DAY_DATES["Thursday"]
    assert_equal Date.new(2026, 2, 27), ScheduleEntry::DAY_DATES["Friday"]
  end
end
