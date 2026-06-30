class RequireMediaTypeOnAlbumReleases < ActiveRecord::Migration[7.1]
  class MigrationMediaType < ActiveRecord::Base
    self.table_name = "media_types"
  end

  class MigrationAlbumRelease < ActiveRecord::Base
    self.table_name = "album_releases"
  end

  def up
    fallback = MigrationMediaType.first || MigrationMediaType.create!(name: "Unknown Format")
    MigrationAlbumRelease.where(media_type_id: nil).update_all(media_type_id: fallback.id)
    change_column_null :album_releases, :media_type_id, false
  end

  def down
    change_column_null :album_releases, :media_type_id, true
  end
end
