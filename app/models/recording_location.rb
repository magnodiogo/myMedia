class RecordingLocation < ApplicationRecord
  has_many :media_recording_location_links, dependent: :destroy
  has_many :media, through: :media_recording_location_links

  validates :name, presence: true, uniqueness: { case_sensitive: false }
end
