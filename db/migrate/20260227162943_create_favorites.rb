class CreateFavorites < ActiveRecord::Migration[8.1]
  def change
    create_table :favorites do |t|
      t.references :user, null: false, foreign_key: true
      t.references :conference_session, null: false, foreign_key: true

      t.timestamps
    end

    add_index :favorites, [ :user_id, :conference_session_id ], unique: true
  end
end
