class AddSlugToMedia < ActiveRecord::Migration[7.1]
  def change
    add_column :media, :slug, :string
    add_index :media, :slug, unique: true
  end
end
