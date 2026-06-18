class CreateArtistsAndReferenceMedia < ActiveRecord::Migration[7.1]
  def up
    create_table :artists do |t|
      t.string :name, null: false
      t.text :bio
      t.timestamps
    end
    add_index :artists, :name, unique: true

    add_reference :media, :artist, foreign_key: true, index: true

    # Migrate existing data safely
    execute <<-SQL
      INSERT INTO artists (name, created_at, updated_at)
      SELECT DISTINCT artist, NOW(), NOW() FROM media;
    SQL

    execute <<-SQL
      UPDATE media
      SET artist_id = artists.id
      FROM artists
      WHERE media.artist = artists.name;
    SQL

    # Make artist_id not null
    change_column_null :media, :artist_id, false

    # Remove old artist column
    remove_column :media, :artist
  end

  def down
    add_column :media, :artist, :string

    execute <<-SQL
      UPDATE media
      SET artist = artists.name
      FROM artists
      WHERE media.artist_id = artists.id;
    SQL

    change_column_null :media, :artist, false

    remove_reference :media, :artist

    drop_table :artists
  end
end
