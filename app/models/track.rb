class Track < ApplicationRecord
  belongs_to :media

  validates :title, presence: true
  validates :track_number, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :duration, format: { with: /\A\d+:\d{2}\z/, message: "must be in MM:SS format" }, allow_blank: true
end

