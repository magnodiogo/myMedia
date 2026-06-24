class MediaGenre < ApplicationRecord
  has_many :media_genre_links, dependent: :destroy
  has_many :media, through: :media_genre_links

  validates :name, presence: true, uniqueness: { case_sensitive: false }
end
