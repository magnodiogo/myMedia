require 'open-uri'
require 'net/http'
require 'json'

class Artist < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged

  has_many :media, dependent: :destroy
  has_one_attached :photo

  attr_accessor :photo_url

  before_save :download_photo_from_url, if: -> { photo_url.present? }

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  def to_s
    name
  end

  def update_bio_from_wikipedia
    summary_data = fetch_wikipedia_summary(name, "en")
    
    if summary_data.nil?
      summary_data = fetch_wikipedia_summary(name, "pt")
    end

    if summary_data && summary_data["extract"].present?
      self.bio = summary_data["extract"]
      save
    else
      false
    end
  end

  def update_photo_from_wikipedia
    image_url = fetch_wikipedia_image_url(name, "en")
    
    if image_url.nil?
      image_url = fetch_wikipedia_image_url(name, "pt")
    end

    if image_url.present?
      self.photo_url = image_url
      save
    else
      false
    end
  end

  private

  def fetch_wikipedia_summary(title, language)
    uri = URI("https://#{language}.wikipedia.org/w/api.php")
    uri.query = URI.encode_www_form(
      action: "query",
      prop: "extracts",
      exintro: true,
      explaintext: true,
      titles: title,
      redirects: 1,
      format: "json"
    )

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    
    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "ColecaoCDs/1.0"
    
    response = http.request(request)
    return nil unless response.code == "200"

    data = JSON.parse(response.body)
    page = data.dig("query", "pages")&.values&.first
    return nil if page.nil? || page["missing"]

    page
  rescue => e
    Rails.logger.error "Wikipedia #{language} fetch error for #{title}: #{e.message}"
    nil
  end

  def fetch_wikipedia_image_url(title, language)
    uri = URI("https://#{language}.wikipedia.org/w/api.php")
    uri.query = URI.encode_www_form(
      action: "query",
      prop: "pageimages",
      piprop: "original",
      titles: title,
      redirects: 1,
      format: "json"
    )

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    
    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "ColecaoCDs/1.0"
    
    response = http.request(request)
    return nil unless response.code == "200"

    data = JSON.parse(response.body)
    page = data.dig("query", "pages")&.values&.first
    return nil if page.nil? || page["missing"]

    page.dig("original", "source")
  rescue => e
    Rails.logger.error "Wikipedia #{language} image fetch error for #{title}: #{e.message}"
    nil
  end

  def download_photo_from_url
    url = photo_url
    self.photo_url = nil

    begin
      file = URI.open(url, "User-Agent" => "ColecaoCDs/1.0", ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE, open_timeout: 5, read_timeout: 5)
      
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
