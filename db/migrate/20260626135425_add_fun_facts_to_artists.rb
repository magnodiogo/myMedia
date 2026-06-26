class AddFunFactsToArtists < ActiveRecord::Migration[7.1]
  def change
    add_column :artists, :fun_facts, :text
  end
end
