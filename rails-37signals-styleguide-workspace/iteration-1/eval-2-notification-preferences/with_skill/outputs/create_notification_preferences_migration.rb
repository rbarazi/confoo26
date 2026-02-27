# db/migrate/XXXXXX_create_notification_preferences.rb

class CreateNotificationPreferences < ActiveRecord::Migration[8.0]
  def change
    create_table :notification_preferences do |t|
      t.references :user, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.string :event_type, null: false
      t.boolean :email_enabled, null: false, default: true

      t.timestamps
    end

    add_index :notification_preferences, [ :user_id, :account_id, :event_type ],
      unique: true, name: "idx_notification_prefs_unique"
  end
end
