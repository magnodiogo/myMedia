class AddAlbumReferenceToTracks < ActiveRecord::Migration[7.1]
  def up
    add_reference :tracks, :album, foreign_key: true
    add_column :tracks, :disc_number, :integer, default: 1, null: false
    add_column :tracks, :musicbrainz_recording_id, :string

    execute <<~SQL.squish
      UPDATE tracks
      SET album_id = media.album_id
      FROM media
      WHERE tracks.media_id = media.id
    SQL

    change_column_null :tracks, :media_id, true

    add_index :tracks, [:album_id, :disc_number, :track_number]
    add_index :tracks, :musicbrainz_recording_id
  end

  def down
    change_column_null :tracks, :media_id, false
    remove_index :tracks, :musicbrainz_recording_id
    remove_index :tracks, [:album_id, :disc_number, :track_number]
    remove_column :tracks, :musicbrainz_recording_id
    remove_column :tracks, :disc_number
    remove_reference :tracks, :album, foreign_key: true
  end
end
