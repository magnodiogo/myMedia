class AddCollectorFieldsToUserMedia < ActiveRecord::Migration[7.1]
  def change
    add_column :user_media, :purchase_location, :string
    add_column :user_media, :price_paid, :decimal, precision: 8, scale: 2
    add_column :user_media, :currency, :string, default: "BRL"
    add_column :user_media, :purchase_date, :date
    add_column :user_media, :physical_location, :string
    add_column :user_media, :condition, :string
    add_column :user_media, :sleeve_condition, :string
    add_column :user_media, :is_signed, :boolean, default: false
    add_column :user_media, :is_sealed, :boolean, default: false
    add_column :user_media, :edition_notes, :string
  end
end
