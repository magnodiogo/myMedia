require "open-uri"
require "net/http"
require "json"

class AlbumRelease < ApplicationRecord
  belongs_to :album
  has_many :media, dependent: :nullify
  has_one_attached :cover_image

  validates :album, presence: true
  validates :title, presence: true
  validates :release_year,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 1800,
              less_than_or_equal_to: ->(_record) { Time.current.year + 5 }
            },
            allow_blank: true
  validates :allmusic_url, uniqueness: true, allow_blank: true

  scope :ordered, -> { order(:release_year, :position, :title, :id) }

  def label_and_catalog
    [label.presence, catalog_number.presence].compact.join(" - ")
  end

  def try_load_cover!
    return true if cover_image.attached?

    cover_url = fetch_cover_from_itunes
    return true if cover_url.present? && download_and_attach_cover(cover_url)

    false
  end

  def display_cover
    cover_image.attached? ? cover_image : album.cover_image
  end

  def display_cover_attached?
    cover_image.attached? || album.cover_image.attached?
  end

  def physical?
    format.to_s.strip.downcase != "digital"
  end

  def to_media
    raise "Digital releases cannot be added to a physical collection" unless physical?

    medium = Media.find_or_initialize_by(album_release: self)
    medium.assign_attributes(
      album: album,
      artist: album.artist,
      media_type: MediaType.for_release_format(format),
      title: title,
      release_year: release_year,
      catalog_number: catalog_number,
      notes: info
    )

    if cover_image.attached? && !medium.cover_image.attached?
      medium.cover_image.attach(cover_image.blob)
    end

    medium.save!
    medium
  end

  private

  def fetch_cover_from_itunes
    search_term = [album.artist&.name, title].compact.join(" ")
    uri = URI("https://itunes.apple.com/search?term=#{ERB::Util.url_encode(search_term)}&entity=album&limit=10")

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
      http.read_timeout = 5
      http.open_timeout = 5
      http.get(uri.request_uri)
    end
    return nil unless response.code == "200"

    data = JSON.parse(response.body)
    best_match = Array(data["results"]).find do |result|
      result["collectionName"].to_s.downcase.include?(album.title.downcase)
    end
    best_match ||= Array(data["results"]).first

    best_match&.dig("artworkUrl100")&.gsub("100x100bb", "600x600bb")
  rescue => e
    Rails.logger.warn "iTunes cover fetch failed for release #{id || title}: #{e.message}"
    nil
  end

  def download_and_attach_cover(url)
    temp_path = nil
    begin
      file = URI.open(url, "User-Agent" => "myMedia/1.0", ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE, open_timeout: 5, read_timeout: 10)
      temp_path = Rails.root.join("tmp", "release-cover-#{SecureRandom.hex(8)}.jpg")
      File.open(temp_path, "wb") { |f| f.write(file.read) }

      system("mogrify -resize '600x600>' -strip #{temp_path}")

      cover_image.attach(io: File.open(temp_path), filename: "release-cover-#{SecureRandom.hex(8)}.jpg", content_type: "image/jpeg")
      File.delete(temp_path) if File.exist?(temp_path)
      save!
      true
    rescue => e
      Rails.logger.error("Failed to download release cover from URL #{url}: #{e.message}")
      File.delete(temp_path) if temp_path && File.exist?(temp_path)
      false
    end
  end
end
