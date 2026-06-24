class CreateAlbumCredits < ActiveRecord::Migration[7.1]
  def change
    create_table :album_credits do |t|
      t.references :media, null: false, foreign_key: true
      t.string :person_name, null: false
      t.string :role, null: false
      t.string :source, null: false
      t.jsonb :raw_data, null: false, default: {}

      t.timestamps
    end

    add_index :album_credits, [:media_id, :source]
    add_index :album_credits, [:media_id, :person_name, :role, :source], name: "index_album_credits_on_media_person_role_source"
  end
end
