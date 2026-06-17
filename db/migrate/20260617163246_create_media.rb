class CreateMedia < ActiveRecord::Migration[7.1]
  def change
    create_table :media do |t|
      t.references :media_type, null: false, foreign_key: true
      t.string :title, null: false
      t.string :artist, null: false
      t.integer :release_year
      t.string :catalog_number
      t.string :barcode
      t.text :notes

      t.timestamps
    end
  end
end
