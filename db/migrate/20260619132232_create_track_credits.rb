class CreateTrackCredits < ActiveRecord::Migration[7.1]
  def change
    create_table :track_credits do |t|
      t.references :track, null: false, foreign_key: true
      t.string :function
      t.string :name

      t.timestamps
    end
  end
end
