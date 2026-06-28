class Track < ApplicationRecord
  belongs_to :media, optional: true
  belongs_to :album, optional: true
  has_many :track_credits, dependent: :destroy

  before_validation :assign_album_from_media

  validates :title, presence: true
  validates :track_number, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :duration, format: { with: /\A\d+:\d{2}\z/, message: "must be in MM:SS format" }, allow_blank: true
  validates :disc_number, numericality: { only_integer: true, greater_than: 0 }, allow_blank: true
  validate :media_or_album_present

  def display_order_key
    natural_position = position.to_s.match(/\A([A-Za-z]*)(\d+)/)

    [
      disc_number || 1,
      natural_position&.[](1).to_s,
      natural_position&.[](2).to_i.nonzero? || track_number || 0,
      track_number || 0,
      id || 0
    ]
  end

  private

  def assign_album_from_media
    self.album ||= media&.album
  end

  def media_or_album_present
    errors.add(:base, "Track must belong to a media item or an album") if media.blank? && album.blank?
  end
end
