class MediaRecordingLocationLink < ApplicationRecord
  belongs_to :media
  belongs_to :recording_location

  validates :recording_location_id, uniqueness: { scope: :media_id }
end
