class Artist < ApplicationRecord
  has_many :media, dependent: :destroy
  has_one_attached :photo

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  def to_s
    name
  end
end
