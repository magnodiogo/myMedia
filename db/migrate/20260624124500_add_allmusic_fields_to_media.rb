class AddAllmusicFieldsToMedia < ActiveRecord::Migration[7.1]
  def change
    add_column :media, :allmusic_url, :string
    add_column :media, :allmusic_imported_at, :datetime
    add_column :media, :allmusic_import_error, :text

    add_index :media, :allmusic_url
  end
end
