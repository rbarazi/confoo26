class CreateConferenceSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :conference_sessions do |t|
      t.string :title, null: false
      t.text :description, null: false
      t.string :slug, null: false
      t.string :tags, array: true, default: []
      t.string :url
      t.references :speaker, null: false, foreign_key: true

      t.timestamps
    end

    add_index :conference_sessions, :slug, unique: true
    add_index :conference_sessions, :tags, using: :gin
  end
end
