class AddInfoToMediaAndPositionToTracks < ActiveRecord::Migration[7.1]
  def change
    add_column :media, :info, :text
    add_column :tracks, :position, :string
  end
end
