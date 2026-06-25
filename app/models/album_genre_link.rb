class AlbumGenreLink < ApplicationRecord
  belongs_to :album
  belongs_to :media_genre

  validates :media_genre_id, uniqueness: { scope: :album_id }
end
