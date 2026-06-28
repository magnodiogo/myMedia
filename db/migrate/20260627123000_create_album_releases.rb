class CreateAlbumReleases < ActiveRecord::Migration[7.1]
  def change
    create_table :album_releases do |t|
      t.references :album, null: false, foreign_key: true
      t.string :title, null: false
      t.integer :release_year
      t.string :format
      t.string :label
      t.string :catalog_number
      t.string :allmusic_url
      t.text :info
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :album_releases, [:album_id, :release_year, :position]
    add_index :album_releases, :allmusic_url, unique: true, where: "allmusic_url IS NOT NULL AND allmusic_url <> ''"
  end
end
