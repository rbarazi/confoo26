require "test_helper"

class SpeakerTest < ActiveSupport::TestCase
  test "valid with required attributes" do
    speaker = speakers(:anna)
    assert speaker.valid?
  end

  test "invalid without name" do
    speaker = Speaker.new(bio: "A bio")
    assert_not speaker.valid?
    assert speaker.errors[:name].any?
  end

  test "invalid without bio" do
    speaker = Speaker.new(name: "Test Speaker")
    assert_not speaker.valid?
    assert speaker.errors[:bio].any?
  end

  test "enforces unique name" do
    duplicate = Speaker.new(name: speakers(:anna).name, bio: "Another bio")
    assert_not duplicate.valid?
    assert duplicate.errors[:name].any?
  end

  test "normalizes name by stripping whitespace" do
    speaker = Speaker.new(name: "  Padded Name  ", bio: "A bio")
    assert_equal "Padded Name", speaker.name
  end

  test "has many conference sessions" do
    speaker = speakers(:anna)
    assert_includes speaker.conference_sessions, conference_sessions(:legacy_code)
  end

  test "can attach a photo" do
    speaker = speakers(:anna)
    speaker.photo.attach(
      io: File.open(Rails.root.join("test/fixtures/files/speaker_photo.jpg")),
      filename: "photo.jpg",
      content_type: "image/jpeg"
    )
    assert speaker.photo.attached?
  end
end
