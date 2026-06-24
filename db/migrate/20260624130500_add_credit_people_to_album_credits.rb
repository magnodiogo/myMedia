class AddCreditPeopleToAlbumCredits < ActiveRecord::Migration[7.1]
  def up
    create_table :credit_people do |t|
      t.string :name, null: false

      t.timestamps
    end
    add_index :credit_people, :name, unique: true

    add_reference :album_credits, :credit_person, foreign_key: { to_table: :credit_people }
    add_column :album_credits, :credit_category, :string, null: false, default: "technical"

    execute <<~SQL.squish
      INSERT INTO credit_people (name, created_at, updated_at)
      SELECT DISTINCT person_name, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM album_credits
      WHERE person_name IS NOT NULL AND person_name <> ''
      ON CONFLICT (name) DO NOTHING
    SQL

    execute <<~SQL.squish
      UPDATE album_credits
      SET credit_person_id = credit_people.id
      FROM credit_people
      WHERE album_credits.person_name = credit_people.name
    SQL

    add_index :album_credits, [:media_id, :credit_person_id, :role, :source], name: "index_album_credits_on_media_person_role_source_id"
    add_index :album_credits, [:credit_person_id, :credit_category]
  end

  def down
    remove_index :album_credits, [:credit_person_id, :credit_category]
    remove_index :album_credits, name: "index_album_credits_on_media_person_role_source_id"
    remove_column :album_credits, :credit_category
    remove_reference :album_credits, :credit_person, foreign_key: { to_table: :credit_people }
    drop_table :credit_people
  end
end
