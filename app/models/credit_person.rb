require "open-uri"
require "net/http"
require "json"

class CreditPerson < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged

  has_many :album_credits, dependent: :restrict_with_error
  has_many :media, through: :album_credits
  has_one_attached :photo

  attr_accessor :photo_url

  before_save :download_photo_from_url, if: -> { photo_url.present? }

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  def to_s
    name
  end

  def update_bio_from_wikipedia
    summary_data = fetch_wikipedia_summary(name, "en") || fetch_wikipedia_summary(name, "pt")
    return false if summary_data.blank? || summary_data["extract"].blank?

    self.bio = summary_data["extract"]
    self.wikipedia_url = summary_data["fullurl"] if summary_data["fullurl"].present?
    save
  end

  def update_photo_from_wikipedia
    image_url = fetch_wikipedia_image_url(name, "en") || fetch_wikipedia_image_url(name, "pt")
    return false if image_url.blank?

    self.photo_url = image_url
    save
  end

  private

  def fetch_wikipedia_summary(title, language)
    uri = URI("https://#{language}.wikipedia.org/w/api.php")
    uri.query = URI.encode_www_form(
      action: "query",
      prop: "extracts|info",
      exintro: true,
      explaintext: true,
      inprop: "url",
      titles: title,
      redirects: 1,
      format: "json"
    )

    response = http_get(uri)
    return nil unless response.code == "200"

    page = JSON.parse(response.body).dig("query", "pages")&.values&.first
    return nil if page.nil? || page["missing"]

    page
  rescue => e
    Rails.logger.error "Wikipedia #{language} fetch error for credit person #{title}: #{e.message}"
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

    response = http_get(uri)
    return nil unless response.code == "200"

    page = JSON.parse(response.body).dig("query", "pages")&.values&.first
    return nil if page.nil? || page["missing"]

    page.dig("original", "source")
  rescue => e
    Rails.logger.error "Wikipedia #{language} image fetch error for credit person #{title}: #{e.message}"
    nil
  end

  def http_get(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE if http.use_ssl?

    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "myMedia/1.0"
    http.request(request)
  end

  def download_photo_from_url
    url = photo_url
    self.photo_url = nil

    file = URI.open(url, "User-Agent" => "myMedia/1.0", ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE, open_timeout: 5, read_timeout: 5)
    temp_path = Rails.root.join("tmp", "credit-person-#{SecureRandom.hex(8)}.jpg")
    File.open(temp_path, "wb") { |f| f.write(file.read) }

    system("mogrify -resize '600x600>' -strip #{temp_path}")

    photo.attach(io: File.open(temp_path), filename: "credit-person-#{SecureRandom.hex(8)}.jpg", content_type: "image/jpeg")
    File.delete(temp_path) if File.exist?(temp_path)
  rescue => e
    Rails.logger.error("Failed to download credit person photo from URL #{url}: #{e.message}")
  end
end
