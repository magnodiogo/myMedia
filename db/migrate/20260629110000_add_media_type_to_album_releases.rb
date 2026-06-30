class AddMediaTypeToAlbumReleases < ActiveRecord::Migration[7.1]
  class MigrationMediaType < ActiveRecord::Base
    self.table_name = "media_types"
  end

  class MigrationAlbumRelease < ActiveRecord::Base
    self.table_name = "album_releases"
  end

  def up
    add_reference :album_releases, :media_type, foreign_key: true

    MigrationAlbumRelease.reset_column_information
    MigrationMediaType.reset_column_information

    MigrationAlbumRelease.find_each do |release|
      media_type = media_type_for_release_format(release.format)
      release.update_columns(media_type_id: media_type.id) if media_type
    end

    remove_column :album_releases, :format, :string
  end

  def down
    add_column :album_releases, :format, :string

    MigrationAlbumRelease.reset_column_information
    MigrationAlbumRelease.find_each do |release|
      release.update_columns(format: MigrationMediaType.find_by(id: release.media_type_id)&.name)
    end

    remove_reference :album_releases, :media_type, foreign_key: true
  end

  private

  def media_type_for_release_format(format)
    normalized = format.to_s.strip
    return MigrationMediaType.first if normalized.blank?

    aliases = {
      "cd" => ["CD RedBook", "CD"],
      "lp" => ["Vinyl LP", "LP"],
      "12 inch vinyl single" => ["Vinyl LP", "12 inch Vinyl Single"],
      "cassette" => ["Cassette Tape", "Cassette"],
      "digital" => ["Digital"],
      "dvd" => ["DVD Audio", "DVD"]
    }

    candidates = aliases.fetch(normalized.downcase, [normalized])
    candidates.each do |candidate|
      media_type = MigrationMediaType.where("LOWER(name) = ?", candidate.downcase).first
      return media_type if media_type
    end

    MigrationMediaType.where("LOWER(name) LIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(normalized.downcase)}%").first ||
      MigrationMediaType.create!(name: candidates.first)
  end
end
