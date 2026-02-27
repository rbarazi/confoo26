class CreateSpeakers < ActiveRecord::Migration[8.1]
  def change
    create_table :speakers do |t|
      t.string :name, null: false
      t.string :company
      t.text :bio, null: false
      t.string :url

      t.timestamps
    end

    add_index :speakers, :name, unique: true
  end
end
