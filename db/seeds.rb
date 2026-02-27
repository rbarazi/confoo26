require "json"

data_dir = Rails.root.join("confoo-2026-data")

# === Step 1: Import Speakers ===
speakers_data = JSON.parse(File.read(data_dir.join("speakers.json")))

speakers_data.each do |attrs|
  speaker = Speaker.find_or_initialize_by(name: attrs["name"])
  speaker.update!(
    company: attrs["company"].presence,
    bio: attrs["bio"],
    url: attrs["url"]
  )

  photo_path = data_dir.join(attrs["photo_local"])
  if photo_path.exist? && !speaker.photo.attached?
    speaker.photo.attach(
      io: File.open(photo_path),
      filename: File.basename(photo_path),
      content_type: "image/jpeg"
    )
  end
end

puts "Imported #{Speaker.count} speakers"

# === Step 2: Build slug lookup from schedule data ===
schedule_data = JSON.parse(File.read(data_dir.join("schedule.json")))
slug_by_session_id = schedule_data.each_with_object({}) do |entry, hash|
  hash[entry["session_id"]] = entry["slug"]
end

# === Step 3: Import Sessions ===
sessions_data = JSON.parse(File.read(data_dir.join("sessions.json")))
session_ids_in_data = sessions_data.map { |s| s["id"] }.to_set

sessions_data.each do |attrs|
  speaker = Speaker.find_by(name: attrs["speaker"])
  unless speaker
    puts "WARNING: Speaker '#{attrs["speaker"]}' not found, skipping session '#{attrs["title"]}'"
    next
  end

  slug = slug_by_session_id[attrs["id"]] || attrs["title"].parameterize

  conference_session = ConferenceSession.find_or_initialize_by(slug: slug)
  conference_session.update!(
    title: attrs["title"],
    description: attrs["description"],
    tags: attrs["tags"] || [],
    url: attrs["url"],
    speaker: speaker
  )
end

# Handle orphan schedule entries (session_ids not in sessions.json)
schedule_data.each do |entry|
  next if session_ids_in_data.include?(entry["session_id"])

  speaker = Speaker.find_by(name: entry["speaker"])
  next unless speaker

  ConferenceSession.find_or_create_by!(slug: entry["slug"]) do |cs|
    cs.title = entry["title"]
    cs.description = "Workshop session"
    cs.tags = []
    cs.speaker = speaker
  end
end

puts "Imported #{ConferenceSession.count} conference sessions"

# === Step 4: Import Schedule Entries ===
schedule_data.each do |entry|
  conference_session = ConferenceSession.find_by(slug: entry["slug"])
  next unless conference_session

  day = ScheduleEntry::DAY_DATES.fetch(entry["day"])
  end_time = entry["end_time"]
  if end_time == entry["start_time"]
    end_time = (Time.parse(entry["start_time"]) + 1.hour).strftime("%H:%M")
    puts "WARNING: Fixed missing end_time for '#{entry["title"]}', defaulting to #{end_time}"
  end

  ScheduleEntry.find_or_initialize_by(conference_session: conference_session).update!(
    day: day,
    start_time: entry["start_time"],
    end_time: end_time,
    room: entry["room"]
  )
end

puts "Imported #{ScheduleEntry.count} schedule entries"
