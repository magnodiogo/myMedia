class MediaStyle < ApplicationRecord
  has_many :media_style_links, dependent: :destroy
  has_many :media, through: :media_style_links

  validates :name, presence: true, uniqueness: { case_sensitive: false }
end
