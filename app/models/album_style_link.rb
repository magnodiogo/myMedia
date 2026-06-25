class AlbumStyleLink < ApplicationRecord
  belongs_to :album
  belongs_to :media_style

  validates :media_style_id, uniqueness: { scope: :album_id }
end
