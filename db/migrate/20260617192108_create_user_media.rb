class CreateUserMedia < ActiveRecord::Migration[7.1]
  class MigrationUser < ActiveRecord::Base
    self.table_name = "users"
  end

  class MigrationMedia < ActiveRecord::Base
    self.table_name = "media"
  end

  class MigrationUserMedia < ActiveRecord::Base
    self.table_name = "user_media"
  end

  def change
    create_table :user_media do |t|
      t.references :user, null: false, foreign_key: true
      t.references :media, null: false, foreign_key: true
      t.text :notes

      t.timestamps
    end

    reversible do |dir|
      dir.up do
        MigrationUser.reset_column_information
        MigrationMedia.reset_column_information
        MigrationUserMedia.reset_column_information

        user = MigrationUser.find_or_create_by!(email: "joao@example.com") do |u|
          u.name = "João"
        end

        MigrationMedia.find_each do |media|
          MigrationUserMedia.find_or_create_by!(
            user_id: user.id,
            media_id: media.id
          ) do |user_media|
            user_media.notes = media.notes
          end
        end
      end
    end
  end
end
