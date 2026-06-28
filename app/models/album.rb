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
  has_many :album_releases, -> { ordered }, dependent: :destroy
  has_many :tracks, -> { order(:disc_number, :track_number) }, dependent: :destroy
  has_many :album_credits, dependent: :destroy
  has_many :credit_people, through: :album_credits
  has_many :album_genre_links, dependent: :destroy
  has_many :media_genres, through: :album_genre_links
  has_many :album_style_links, dependent: :destroy
  has_many :media_styles, through: :album_style_links
  has_many :album_recording_location_links, dependent: :destroy
  has_many :recording_locations, through: :album_recording_location_links

  has_one_attached :cover_image

  attr_accessor :cover_url
  attr_writer :manual_credits_text

  before_save :download_cover_from_url, if: -> { cover_url.present? && !cover_image.attached? }
  before_save :persist_manual_credits, if: -> { @manual_credits_dirty }

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
    tracks.includes(:track_credits).to_a.sort_by(&:display_order_key)
  end

  def participant_credits
    display_tracks.flat_map(&:track_credits).group_by(&:name).sort_by { |name, _credits| name.to_s.downcase }
  end

  def import_allmusic!
    find_allmusic_url! if allmusic_url.blank?
    Allmusic::ImportAlbumService.call(self)
  end

  def find_allmusic_url!
    found_url = Allmusic::AlbumSearchService.call(self)
    update!(allmusic_url: found_url) if found_url.present?
    found_url
  end

  def formatted_duration
    return nil if duration_seconds.blank?

    minutes = duration_seconds / 60
    seconds = duration_seconds % 60
    format("%d:%02d", minutes, seconds)
  end

  def genre_names
    media_genres.map(&:name).join(", ")
  end

  def genre_names=(names_string)
    self.media_genres = names_string.to_s.split(/\s*,\s*/).map(&:strip).reject(&:empty?).map do |name|
      MediaGenre.where("LOWER(name) = ?", name.downcase).first || MediaGenre.create!(name: name)
    end
  end

  def style_names
    media_styles.map(&:name).join(", ")
  end

  def style_names=(names_string)
    self.media_styles = names_string.to_s.split(/\s*,\s*/).map(&:strip).reject(&:empty?).map do |name|
      MediaStyle.where("LOWER(name) = ?", name.downcase).first || MediaStyle.create!(name: name)
    end
  end

  def recording_location_names
    recording_locations.map(&:name).join(", ")
  end

  def recording_location_names=(names_string)
    self.recording_locations = names_string.to_s.split(/\s*,\s*/).map(&:strip).reject(&:empty?).map do |name|
      RecordingLocation.where("LOWER(name) = ?", name.downcase).first || RecordingLocation.create!(name: name)
    end
  end

  def formatted_duration=(value)
    if value.blank?
      self.duration_seconds = nil
    else
      parts = value.to_s.split(":").map(&:to_i)
      if parts.size == 2
        self.duration_seconds = (parts[0] * 60) + parts[1]
      elsif parts.size == 1
        self.duration_seconds = parts[0]
      end
    end
  end

  def manual_credits_text
    @manual_credits_text || album_credits.order(:person_name, :role).map { |c| "#{c.person_name} - #{c.role}" }.join("\n")
  end

  def manual_credits_text=(text)
    @manual_credits_text = text
    @manual_credits_dirty = true
  end

  def try_load_cover!
    return true if cover_image.attached?

    # 1. Try iTunes Search API
    itunes_url = fetch_cover_from_itunes
    if itunes_url.present?
      return true if download_and_attach_cover(itunes_url)
    end

    # 2. Try Discogs Search API
    discogs_url = fetch_cover_from_discogs
    if discogs_url.present?
      return true if download_and_attach_cover(discogs_url)
    end

    # 3. Fallback: if we have musicbrainz_release_group_id
    if musicbrainz_release_group_id.present?
      caa_url = "https://coverartarchive.org/release-group/#{musicbrainz_release_group_id}/front"
      return true if download_and_attach_cover(caa_url)
    end

    false
  end

  private

  def fetch_cover_from_itunes
    search_term = "#{artist&.name} #{title}"
    url = "https://itunes.apple.com/search?term=#{ERB::Util.url_encode(search_term)}&entity=album&limit=5"
    uri = URI(url)
    
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
      http.read_timeout = 5
      http.open_timeout = 5
      http.get(uri.request_uri)
    end

    if response.code == '200'
      data = JSON.parse(response.body)
      if data["results"] && data["results"].any?
        best_match = data["results"].find do |result|
          result["collectionName"].to_s.downcase.include?(title.downcase) ||
            title.downcase.include?(result["collectionName"].to_s.downcase)
        end
        best_match ||= data["results"].first
        artwork_url = best_match["artworkUrl100"]
        return artwork_url.gsub("100x100bb", "600x600bb") if artwork_url.present?
      end
    end
    nil
  rescue => e
    Rails.logger.warn "iTunes cover fetch failed for #{title}: #{e.message}"
    nil
  end

  def fetch_cover_from_discogs
    token = ENV["DISCOGS_TOKEN"] || "TPfEJXlWcimuwWmFvvENlMGtyHbvJtqhsSzbpjuX"
    search_term = "#{artist&.name} #{title}"
    uri = URI("https://api.discogs.com/database/search?q=#{ERB::Util.url_encode(search_term)}&type=release")

    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Discogs Token #{token}"
    request["User-Agent"] = "myMedia/1.0"

    response = http.request(request)
    if response.code == '200'
      data = JSON.parse(response.body)
      if data["results"] && data["results"].any?
        best_match = data["results"].find do |result|
          result["title"].to_s.downcase.include?(title.downcase)
        end
        best_match ||= data["results"].first
        cover_url = best_match["cover_image"].presence || best_match["thumb"].presence
        return cover_url if cover_url.present?
      end
    end
    nil
  rescue => e
    Rails.logger.warn "Discogs cover fetch failed for #{title}: #{e.message}"
    nil
  end

  def download_and_attach_cover(url)
    temp_path = nil
    begin
      file = URI.open(url, "User-Agent" => "myMedia/1.0", ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE, open_timeout: 5, read_timeout: 10)
      temp_path = Rails.root.join("tmp", "album-cover-#{SecureRandom.hex(8)}.jpg")
      File.open(temp_path, "wb") { |f| f.write(file.read) }

      system("mogrify -resize '600x600>' -strip #{temp_path}")

      cover_image.attach(io: File.open(temp_path), filename: "album-cover-#{SecureRandom.hex(8)}.jpg", content_type: "image/jpeg")
      File.delete(temp_path) if File.exist?(temp_path)
      
      save!
      true
    rescue => e
      Rails.logger.error("Failed to download and attach album cover from URL #{url}: #{e.message}")
      File.delete(temp_path) if temp_path && File.exist?(temp_path)
      false
    end
  end

  def persist_manual_credits
    parsed_credits = @manual_credits_text.to_s.split("\n").map(&:strip).reject(&:empty?).map do |line|
      parts = line.split(/\s*-\s*/, 2)
      next nil if parts.size < 2

      { person_name: parts[0].strip, role: parts[1].strip }
    end.compact

    self.album_credits = parsed_credits.map do |pc|
      person = CreditPerson.where("LOWER(name) = ?", pc[:person_name].downcase).first || CreditPerson.create!(name: pc[:person_name])
      AlbumCredit.new(
        credit_person: person,
        person_name: pc[:person_name],
        role: pc[:role],
        source: "manual"
      )
    end
  end

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
