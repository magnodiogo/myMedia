class AddLifeDatesToCreditPeople < ActiveRecord::Migration[7.1]
  def change
    add_column :credit_people, :birth_date, :date
    add_column :credit_people, :birth_place, :string
    add_column :credit_people, :death_date, :date
    add_column :credit_people, :death_place, :string
  end
end
