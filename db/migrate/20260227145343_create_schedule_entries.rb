class CreateScheduleEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :schedule_entries do |t|
      t.date :day, null: false
      t.time :start_time, null: false
      t.time :end_time, null: false
      t.string :room, null: false
      t.references :conference_session, null: false, foreign_key: true, index: { unique: true }

      t.timestamps
    end
    add_index :schedule_entries, [ :day, :start_time, :room ], unique: true
  end
end
