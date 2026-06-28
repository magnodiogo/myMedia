class CollectionListItem < ApplicationRecord
  belongs_to :collection_list
  belongs_to :media

  validates :collection_list, presence: true
  validates :media, presence: true
  validates :media_id, uniqueness: { scope: :collection_list_id }

  scope :ordered, -> { order(:position, :id) }
end
