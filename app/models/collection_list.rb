class CollectionList < ApplicationRecord
  LIST_TYPES = [
    "essential_albums",
    "audiophile_reference",
    "grammy_winners",
    "genre_guide",
    "artist_discography",
    "custom"
  ].freeze

  has_many :collection_list_items, dependent: :destroy
  has_many :media, through: :collection_list_items

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :list_type, presence: true, inclusion: { in: LIST_TYPES }

  scope :ordered, -> { order(:position, :name) }
end
