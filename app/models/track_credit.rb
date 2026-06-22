class TrackCredit < ApplicationRecord
  belongs_to :track

  validates :function, presence: true
  validates :name, presence: true
end
