class CreateCollectionListItems < ActiveRecord::Migration[7.1]
  def change
    create_table :collection_list_items do |t|
      t.references :collection_list, null: false, foreign_key: true
      t.references :media, null: false, foreign_key: true
      t.integer :position, default: 0, null: false
      t.text :notes

      t.timestamps
    end

    add_index :collection_list_items, [:collection_list_id, :media_id], unique: true
    add_index :collection_list_items, [:collection_list_id, :position]
  end
end
