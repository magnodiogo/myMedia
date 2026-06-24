class CreateAlbumsAndLinkMedia < ActiveRecord::Migration[7.1]
  def up
    create_table :albums do |t|
      t.references :artist, null: false, foreign_key: true
      t.string :title, null: false
      t.integer :album_type, null: false, default: 0
      t.integer :metadata_status, null: false, default: 0
      t.integer :release_year
      t.date :original_release_date
      t.text :summary
      t.string :slug
      t.string :musicbrainz_release_group_id
      t.string :wikidata_id
      t.string :wikipedia_url

      t.timestamps
    end

    add_index :albums, :slug, unique: true
    add_index :albums, [:artist_id, :title, :release_year]
    add_index :albums, :musicbrainz_release_group_id, unique: true
    add_index :albums, :wikidata_id

    add_reference :media, :album, foreign_key: true

    execute <<~SQL.squish
      INSERT INTO albums (
        artist_id,
        title,
        release_year,
        summary,
        created_at,
        updated_at
      )
      SELECT
        media.artist_id,
        media.title,
        media.release_year,
        MAX(media.info),
        NOW(),
        NOW()
      FROM media
      GROUP BY media.artist_id, media.title, media.release_year
    SQL

    execute <<~SQL.squish
      UPDATE media
      SET album_id = albums.id
      FROM albums
      WHERE media.artist_id = albums.artist_id
        AND media.title = albums.title
        AND media.release_year IS NOT DISTINCT FROM albums.release_year
    SQL

    change_column_null :media, :album_id, false
  end

  def down
    remove_reference :media, :album, foreign_key: true
    drop_table :albums
  end
end
