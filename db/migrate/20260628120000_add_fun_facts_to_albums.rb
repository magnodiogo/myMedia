class AddFunFactsToAlbums < ActiveRecord::Migration[7.1]
  def change
    add_column :albums, :fun_facts, :text
  end
end
