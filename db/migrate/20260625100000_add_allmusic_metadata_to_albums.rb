class AddAllmusicMetadataToAlbums < ActiveRecord::Migration[7.1]
  def change
    add_column :albums, :allmusic_url, :string
    add_column :albums, :allmusic_imported_at, :datetime
    add_column :albums, :allmusic_import_error, :text
    add_column :albums, :duration_seconds, :integer

    add_index :albums, :allmusic_url
    add_index :albums, :duration_seconds

    execute <<~SQL.squish
      UPDATE albums
      SET allmusic_url = media_links.allmusic_url
      FROM (
        SELECT DISTINCT ON (album_id) album_id, allmusic_url
        FROM media
        WHERE allmusic_url IS NOT NULL AND allmusic_url <> ''
        ORDER BY album_id, id
      ) media_links
      WHERE albums.id = media_links.album_id
    SQL

    create_table :album_genre_links do |t|
      t.references :album, null: false, foreign_key: true
      t.references :media_genre, null: false, foreign_key: true

      t.timestamps
    end
    add_index :album_genre_links, [:album_id, :media_genre_id], unique: true

    create_table :album_style_links do |t|
      t.references :album, null: false, foreign_key: true
      t.references :media_style, null: false, foreign_key: true

      t.timestamps
    end
    add_index :album_style_links, [:album_id, :media_style_id], unique: true

    create_table :album_recording_location_links do |t|
      t.references :album, null: false, foreign_key: true
      t.references :recording_location, null: false, foreign_key: true

      t.timestamps
    end
    add_index :album_recording_location_links, [:album_id, :recording_location_id], unique: true, name: "index_album_recording_locations_unique"

    add_reference :album_credits, :album, foreign_key: true
    change_column_null :album_credits, :media_id, true
    add_index :album_credits, [:album_id, :source]
    add_index :album_credits, [:album_id, :person_name, :role, :source], name: "index_album_credits_on_album_person_role_source"
    add_index :album_credits, [:album_id, :credit_person_id, :role, :source], name: "index_album_credits_on_album_person_role_source_id"
  end
end
