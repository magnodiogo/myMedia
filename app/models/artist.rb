require 'open-uri'
require 'net/http'
require 'json'

class Artist < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged

  has_many :media, dependent: :destroy
  has_many :albums, dependent: :destroy
  has_one_attached :photo
  has_one_attached :banner

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

  def load_discography
    musicbrainz_artist = fetch_musicbrainz_artist
    return { imported: 0, updated: 0, skipped: 0, error: "Artist not found on MusicBrainz." } if musicbrainz_artist.blank?

    imported = 0
    updated = 0
    skipped = 0

    fetch_musicbrainz_release_groups(musicbrainz_artist["id"]).each do |release_group|
      album = album_for_release_group(release_group)
      next skipped += 1 if album.nil?

      album.assign_attributes(album_attributes_from_release_group(release_group))
      album.cover_url = cover_art_archive_url(release_group["id"]) if album.musicbrainz_release_group_id.present? && !album.cover_image.attached?

      if album.new_record?
        album.save!
        imported += 1
      elsif album.changed? || album.cover_url.present?
        album.save!
        updated += 1
      else
        skipped += 1
      end
    rescue => e
      Rails.logger.error("Failed to import release group #{release_group["id"]}: #{e.message}")
      skipped += 1
    end

    { imported: imported, updated: updated, skipped: skipped, error: nil }
  end

  def initials
    return "" if name.blank?
    parts = name.strip.split(/\s+/)
    if parts.length > 1
      (parts.first[0] + parts.last[0]).upcase
    else
      parts.first[0..1].upcase
    end
  end

  private

  MUSICBRAINZ_BASE_URL = "https://musicbrainz.org/ws/2".freeze
  MUSICBRAINZ_USER_AGENT = "myMedia/1.0".freeze

  def fetch_musicbrainz_artist
    uri = URI("#{MUSICBRAINZ_BASE_URL}/artist")
    uri.query = URI.encode_www_form(
      query: %(artist:"#{name.to_s.gsub('"', '')}"),
      fmt: "json",
      limit: 5
    )

    data = fetch_json(uri, "MusicBrainz artist")
    artists = data&.fetch("artists", [])
    exact_match = artists.find { |artist| artist["name"].to_s.casecmp(name.to_s).zero? }
    exact_match || artists.first
  end

  def fetch_musicbrainz_release_groups(musicbrainz_artist_id)
    release_groups = []
    offset = 0
    limit = 100

    loop do
      uri = URI("#{MUSICBRAINZ_BASE_URL}/release-group")
      uri.query = URI.encode_www_form(
        artist: musicbrainz_artist_id,
        fmt: "json",
        limit: limit,
        offset: offset
      )

      data = fetch_json(uri, "MusicBrainz release groups")
      batch = data&.fetch("release-groups", []) || []
      release_groups.concat(batch.select { |release_group| importable_release_group?(release_group) })

      total = data&.fetch("release-group-count", 0).to_i
      offset += limit
      break if batch.empty? || offset >= total

      sleep 1.0
    end

    release_groups.sort_by { |release_group| [release_group["first-release-date"].to_s, release_group["title"].to_s] }
  end

  def fetch_json(uri, context)
    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE if http.use_ssl?

    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = MUSICBRAINZ_USER_AGENT

    response = http.request(request)
    return nil unless response.code.to_i.between?(200, 299)

    JSON.parse(response.body)
  rescue => e
    Rails.logger.error("#{context} fetch error for #{name}: #{e.message}")
    nil
  end

  def importable_release_group?(release_group)
    album_type_from_release_group(release_group).present?
  end

  def album_for_release_group(release_group)
    musicbrainz_id = release_group["id"].presence
    title = release_group["title"].to_s.strip
    return nil if title.blank?

    if musicbrainz_id.present?
      existing = albums.find_by(musicbrainz_release_group_id: musicbrainz_id)
      return existing if existing
    end

    albums.find_or_initialize_by(
      title: title,
      release_year: release_year_from_release_group(release_group)
    )
  end

  def album_attributes_from_release_group(release_group)
    {
      title: release_group["title"].to_s.strip,
      release_year: release_year_from_release_group(release_group),
      original_release_date: release_date_from_release_group(release_group),
      album_type: album_type_from_release_group(release_group),
      metadata_status: :imported,
      musicbrainz_release_group_id: release_group["id"]
    }
  end

  def album_type_from_release_group(release_group)
    primary_type = release_group["primary-type"].to_s.downcase
    secondary_types = Array(release_group["secondary-types"]).map { |type| type.to_s.downcase }

    return :live if secondary_types.include?("live")
    return :compilation if secondary_types.include?("compilation")
    return :soundtrack if secondary_types.include?("soundtrack")

    case primary_type
    when "album" then :studio
    when "ep" then :ep
    when "single" then :single
    else nil
    end
  end

  def release_year_from_release_group(release_group)
    release_group["first-release-date"].to_s[/\A\d{4}/]&.to_i
  end

  def release_date_from_release_group(release_group)
    date = release_group["first-release-date"].to_s
    return nil unless date.match?(/\A\d{4}-\d{2}-\d{2}\z/)

    Date.parse(date)
  rescue ArgumentError
    nil
  end

  def cover_art_archive_url(musicbrainz_release_group_id)
    "https://coverartarchive.org/release-group/#{musicbrainz_release_group_id}/front"
  end

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
    request["User-Agent"] = "myMedia/1.0"
    
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
    request["User-Agent"] = "myMedia/1.0"
    
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
      file = URI.open(url, "User-Agent" => "myMedia/1.0", ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE, open_timeout: 5, read_timeout: 5)
      
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
