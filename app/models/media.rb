require 'open-uri'

class Media < ApplicationRecord
  extend FriendlyId
  friendly_id :title, use: :slugged

  belongs_to :media_type
  belongs_to :artist
  belongs_to :album
  belongs_to :album_release, optional: true
  has_one_attached :cover_image

  has_many :user_media, class_name: "UserMedia", dependent: :destroy
  has_many :users, through: :user_media
  has_many :tracks, -> { order(track_number: :asc) }, dependent: :destroy
  has_many :album_credits, dependent: :destroy
  has_many :credit_people, through: :album_credits
  has_many :media_genre_links, dependent: :destroy
  has_many :media_genres, through: :media_genre_links
  has_many :media_style_links, dependent: :destroy
  has_many :media_styles, through: :media_style_links
  has_many :media_recording_location_links, dependent: :destroy
  has_many :recording_locations, through: :media_recording_location_links
  has_many :collection_list_items, dependent: :destroy
  has_many :collection_lists, through: :collection_list_items


  attr_accessor :cover_url

  before_validation :assign_album_from_media_attributes, if: -> { album.blank? && title.present? && artist.present? }
  before_save :sync_allmusic_url_to_album, if: -> { allmusic_url.present? && album.present? }
  before_save :download_cover_from_url, if: -> { cover_url.present? }
  after_create_commit :enrich_metadata, if: -> { !Rails.env.test? }

  validates :title, presence: true
  validates :artist, presence: true
  validates :release_year, numericality: { 
    only_integer: true, 
    greater_than_or_equal_to: 1800, 
    less_than_or_equal_to: ->(_record) { Time.current.year + 5 } 
  }, allow_blank: true

  def artist=(value)
    if value.is_a?(String)
      if value.strip.present?
        super(Artist.find_or_create_by(name: value.strip))
      else
        super(nil)
      end
    else
      super(value)
    end
  end

  def import_allmusic!
    Allmusic::ImportAlbumService.call(self)
  end

  def formatted_duration
    return nil if duration_seconds.blank?

    minutes = duration_seconds / 60
    seconds = duration_seconds % 60
    format("%d:%02d", minutes, seconds)
  end

  private

  def assign_album_from_media_attributes
    self.album = Album.find_or_initialize_by(
      artist: artist,
      title: title,
      release_year: release_year
    )

    album.summary ||= info if info.present?
  end

  def download_cover_from_url
    url = cover_url
    self.cover_url = nil

    begin
      file = URI.open(url, "User-Agent" => "myMedia/1.0", ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE, open_timeout: 5, read_timeout: 5)
      
      temp_path = Rails.root.join("tmp", "cover-#{SecureRandom.hex(8)}.jpg")
      File.open(temp_path, "wb") { |f| f.write(file.read) }
      
      # Resize cover image to max 600x600 and strip metadata to save disk space
      system("mogrify -resize '600x600>' -strip #{temp_path}")
      
      cover_image.attach(io: File.open(temp_path), filename: "cover-#{SecureRandom.hex(8)}.jpg", content_type: "image/jpeg")
      
      File.delete(temp_path) if File.exist?(temp_path)
    rescue => e
      Rails.logger.error("Failed to download cover from URL #{url}: #{e.message}")
    end
  end

  def sync_allmusic_url_to_album
    album.allmusic_url ||= allmusic_url
  end

  def enrich_metadata
    Thread.new do
      Rails.application.executor.wrap do
        MediaEnrichmentService.new(self).perform
      end
    end
  end
end
