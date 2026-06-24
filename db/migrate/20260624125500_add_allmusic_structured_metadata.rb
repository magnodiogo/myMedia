class AddAllmusicStructuredMetadata < ActiveRecord::Migration[7.1]
  def change
    add_column :media, :duration_seconds, :integer
    add_index :media, :duration_seconds

    create_table :media_genres do |t|
      t.string :name, null: false

      t.timestamps
    end
    add_index :media_genres, :name, unique: true

    create_table :media_genre_links do |t|
      t.references :media, null: false, foreign_key: true
      t.references :media_genre, null: false, foreign_key: true

      t.timestamps
    end
    add_index :media_genre_links, [:media_id, :media_genre_id], unique: true

    create_table :media_styles do |t|
      t.string :name, null: false

      t.timestamps
    end
    add_index :media_styles, :name, unique: true

    create_table :media_style_links do |t|
      t.references :media, null: false, foreign_key: true
      t.references :media_style, null: false, foreign_key: true

      t.timestamps
    end
    add_index :media_style_links, [:media_id, :media_style_id], unique: true

    create_table :recording_locations do |t|
      t.string :name, null: false

      t.timestamps
    end
    add_index :recording_locations, :name, unique: true

    create_table :media_recording_location_links do |t|
      t.references :media, null: false, foreign_key: true
      t.references :recording_location, null: false, foreign_key: true

      t.timestamps
    end
    add_index :media_recording_location_links, [:media_id, :recording_location_id], unique: true, name: "index_media_recording_locations_unique"
  end
end
