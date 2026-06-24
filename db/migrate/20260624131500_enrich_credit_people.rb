class EnrichCreditPeople < ActiveRecord::Migration[7.1]
  def change
    add_column :credit_people, :bio, :text
    add_column :credit_people, :slug, :string
    add_column :credit_people, :wikipedia_url, :string
    add_column :credit_people, :allmusic_url, :string

    add_index :credit_people, :slug, unique: true
    add_index :credit_people, :allmusic_url
  end
end
