class AddLyricsToTracks < ActiveRecord::Migration[7.1]
  def change
    add_column :tracks, :lyrics, :text
  end
end
