class CreateUserMedia < ActiveRecord::Migration[7.1]
  def change
    create_table :user_media do |t|
      t.references :user, null: false, foreign_key: true
      t.references :media, null: false, foreign_key: true
      t.text :notes

      t.timestamps
    end

    reversible do |dir|
      dir.up do
        # Enforce model classes to be loaded
        User.reset_column_information
        UserMedia.reset_column_information
        Media.reset_column_information

        # Ensure at least one user exists
        user = User.find_or_create_by!(email: "joao@example.com") do |u|
          u.name = "João"
        end

        # Link all existing media to this user
        Media.all.each do |m|
          UserMedia.find_or_create_by!(user: user, media: m) do |um|
            um.notes = m.notes
          end
        end
      end
    end
  end
end
