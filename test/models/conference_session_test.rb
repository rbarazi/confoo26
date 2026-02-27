require "test_helper"

class ConferenceSessionTest < ActiveSupport::TestCase
  test "valid with required attributes" do
    session = conference_sessions(:legacy_code)
    assert session.valid?
  end

  test "invalid without title" do
    session = ConferenceSession.new(description: "Desc", speaker: speakers(:anna))
    assert_not session.valid?
    assert session.errors[:title].any?
  end

  test "invalid without description" do
    session = ConferenceSession.new(title: "Title", speaker: speakers(:anna))
    assert_not session.valid?
    assert session.errors[:description].any?
  end

  test "generates slug from title on create" do
    session = ConferenceSession.create!(
      title: "My Great Talk",
      description: "A description",
      speaker: speakers(:anna)
    )
    assert_equal "my-great-talk", session.slug
  end

  test "does not overwrite explicit slug" do
    session = ConferenceSession.create!(
      title: "My Great Talk",
      description: "A description",
      slug: "custom-slug",
      speaker: speakers(:anna)
    )
    assert_equal "custom-slug", session.slug
  end

  test "enforces unique slug" do
    duplicate = ConferenceSession.new(
      title: "Different Title",
      description: "Desc",
      slug: conference_sessions(:legacy_code).slug,
      speaker: speakers(:anna)
    )
    assert_not duplicate.valid?
    assert duplicate.errors[:slug].any?
  end

  test "tagged scope finds sessions by tag" do
    results = ConferenceSession.tagged("ai")
    assert_includes results, conference_sessions(:agentic_ai)
    assert_not_includes results, conference_sessions(:legacy_code)
  end

  test "scheduled scope returns only scheduled sessions" do
    results = ConferenceSession.scheduled
    assert_includes results, conference_sessions(:legacy_code)
    assert_not_includes results, conference_sessions(:unscheduled)
  end

  test "unscheduled scope returns only unscheduled sessions" do
    results = ConferenceSession.unscheduled
    assert_includes results, conference_sessions(:unscheduled)
    assert_not_includes results, conference_sessions(:legacy_code)
  end

  test "belongs to speaker" do
    session = conference_sessions(:legacy_code)
    assert_equal speakers(:anna), session.speaker
  end

  test "has one schedule entry" do
    session = conference_sessions(:legacy_code)
    assert_equal schedule_entries(:wednesday_legacy), session.schedule_entry
  end
end
