class MediaGenreLink < ApplicationRecord
  belongs_to :media
  belongs_to :media_genre

  validates :media_genre_id, uniqueness: { scope: :media_id }
end
