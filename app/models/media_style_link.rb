class MediaStyleLink < ApplicationRecord
  belongs_to :media
  belongs_to :media_style

  validates :media_style_id, uniqueness: { scope: :media_id }
end
