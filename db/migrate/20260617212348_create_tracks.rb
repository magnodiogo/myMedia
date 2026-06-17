class CreateTracks < ActiveRecord::Migration[7.1]
  def change
    create_table :tracks do |t|
      t.references :media, null: false, foreign_key: true
      t.string :title, null: false
      t.integer :track_number, null: false
      t.string :duration


      t.timestamps
    end
  end
end
