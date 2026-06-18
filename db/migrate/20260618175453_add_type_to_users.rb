class AddTypeToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :type, :string, default: 'CommonUser', null: false
  end
end
