require 'open-uri'

class Media < ApplicationRecord
  belongs_to :media_type
  belongs_to :artist
  has_one_attached :cover_image

  has_many :user_media, class_name: "UserMedia", dependent: :destroy
  has_many :users, through: :user_media
  has_many :tracks, -> { order(track_number: :asc) }, dependent: :destroy


  attr_accessor :cover_url

  before_save :download_cover_from_url, if: -> { cover_url.present? }

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

  private

  def download_cover_from_url
    url = cover_url
    self.cover_url = nil

    begin
      file = URI.open(url, ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE)
      
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
end
