class MediaType < ApplicationRecord
  has_many :media, class_name: "Media", dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { case_sensitive: false }
end
