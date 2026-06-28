class AddAlbumReleaseToMedia < ActiveRecord::Migration[7.1]
  def change
    add_reference :media, :album_release, foreign_key: true, index: false
    add_index :media, :album_release_id, unique: true
  end
end
