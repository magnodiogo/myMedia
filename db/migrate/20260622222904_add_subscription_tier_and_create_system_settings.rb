class AddSubscriptionTierAndCreateSystemSettings < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :subscription_tier, :string, default: "free", null: false

    create_table :system_settings do |t|
      t.string :key, null: false
      t.string :value
      t.timestamps
    end

    add_index :system_settings, :key, unique: true
  end
end
