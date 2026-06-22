class AddPreferencesToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :theme, :string, default: "dark"
    add_column :users, :sidebar_collapsed, :boolean, default: false
    add_column :users, :view_preference, :string, default: "detailed"
    add_column :users, :media_card_size, :integer, default: 180
  end
end