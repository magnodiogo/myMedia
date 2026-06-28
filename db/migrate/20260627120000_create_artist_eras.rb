class CreateArtistEras < ActiveRecord::Migration[7.1]
  def change
    create_table :artist_eras do |t|
      t.references :artist, null: false, foreign_key: true
      t.string :name, null: false
      t.date :starts_on
      t.date :ends_on
      t.text :description
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :artist_eras, [:artist_id, :position]
  end
end
