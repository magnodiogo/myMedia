class AlbumRecordingLocationLink < ApplicationRecord
  belongs_to :album
  belongs_to :recording_location

  validates :recording_location_id, uniqueness: { scope: :album_id }
end
