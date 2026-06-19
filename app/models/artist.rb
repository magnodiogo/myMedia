require 'open-uri'

class Artist < ApplicationRecord
  has_many :media, dependent: :destroy
  has_one_attached :photo

  attr_accessor :photo_url

  before_save :download_photo_from_url, if: -> { photo_url.present? }

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  def to_s
    name
  end

  private

  def download_photo_from_url
    url = photo_url
    self.photo_url = nil

    begin
      file = URI.open(url, ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE)
      
      temp_path = Rails.root.join("tmp", "photo-#{SecureRandom.hex(8)}.jpg")
      File.open(temp_path, "wb") { |f| f.write(file.read) }
      
      # Resize image to max 600x600 and strip metadata to save disk space
      system("mogrify -resize '600x600>' -strip #{temp_path}")
      
      photo.attach(io: File.open(temp_path), filename: "artist-#{SecureRandom.hex(8)}.jpg", content_type: "image/jpeg")
      
      File.delete(temp_path) if File.exist?(temp_path)
    rescue => e
      Rails.logger.error("Failed to download artist photo from URL #{url}: #{e.message}")
    end
  end
end
