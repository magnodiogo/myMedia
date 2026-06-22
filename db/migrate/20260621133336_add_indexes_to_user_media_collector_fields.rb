class AddIndexesToUserMediaCollectorFields < ActiveRecord::Migration[7.1]
  def change
    add_index :user_media, :condition
    add_index :user_media, :sleeve_condition
    add_index :user_media, :purchase_location
  end
end
