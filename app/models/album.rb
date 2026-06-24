require "open-uri"

class Album < ApplicationRecord
  extend FriendlyId
  friendly_id :slug_candidates, use: :slugged

  enum album_type: {
    studio: 0,
    live: 1,
    compilation: 2,
    soundtrack: 3,
    ep: 4,
    single: 5,
    box_set: 6
  }

  enum metadata_status: {
    pending: 0,
    imported: 1,
    reviewed: 2,
    curated: 3
  }

  belongs_to :artist

  has_many :media, dependent: :restrict_with_error
  has_many :tracks, -> { order(:disc_number, :track_number) }, dependent: :destroy

  has_one_attached :cover_image

  attr_accessor :cover_url

  before_save :download_cover_from_url, if: -> { cover_url.present? && !cover_image.attached? }

  validates :title, presence: true
  validates :artist, presence: true
  validates :release_year,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 1800,
              less_than_or_equal_to: ->(_record) { Time.current.year + 5 }
            },
            allow_blank: true

  def to_s
    title
  end

  def primary_artist
    artist
  end

  def primary_artist=(value)
    self.artist = value
  end

  def canonical_media
    media.includes(tracks: :track_credits).detect { |medium| medium.tracks.any? } || media.first
  end

  def display_tracks
    tracks.includes(:track_credits).order(:disc_number, :track_number)
  end

  def participant_credits
    display_tracks.flat_map(&:track_credits).group_by(&:name).sort_by { |name, _credits| name.to_s.downcase }
  end

  private

  def slug_candidates
    [
      :title,
      [:title, artist&.name],
      [:title, artist&.name, release_year]
    ]
  end

  def download_cover_from_url
    url = cover_url
    self.cover_url = nil

    begin
      file = URI.open(url, "User-Agent" => "myMedia/1.0", ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE, open_timeout: 5, read_timeout: 10)
      temp_path = Rails.root.join("tmp", "album-cover-#{SecureRandom.hex(8)}.jpg")
      File.open(temp_path, "wb") { |f| f.write(file.read) }

      system("mogrify -resize '600x600>' -strip #{temp_path}")

      cover_image.attach(io: File.open(temp_path), filename: "album-cover-#{SecureRandom.hex(8)}.jpg", content_type: "image/jpeg")
      File.delete(temp_path) if File.exist?(temp_path)
    rescue => e
      Rails.logger.error("Failed to download album cover from URL #{url}: #{e.message}")
    end
  end
end
