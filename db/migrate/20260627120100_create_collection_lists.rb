class CreateCollectionLists < ActiveRecord::Migration[7.1]
  def change
    create_table :collection_lists do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.string :list_type, null: false
      t.boolean :public, default: true, null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :collection_lists, :slug, unique: true
    add_index :collection_lists, [:list_type, :position]
  end
end
