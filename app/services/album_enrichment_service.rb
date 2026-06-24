require "net/http"
require "json"
require "uri"
require "openssl"

class AlbumEnrichmentService
  class HttpClient
    def self.get_json(uri, headers = {})
      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE if http.use_ssl?

      request = Net::HTTP::Get.new(uri)
      headers.each { |key, value| request[key] = value }

      response = http.request(request)
      raise "HTTP Error #{response.code}: #{response.body}" unless response.code.to_i.between?(200, 299)

      JSON.parse(response.body)
    end
  end

  USER_AGENT = "myMedia/1.0 (album metadata import)"
  MUSICBRAINZ_URL = "https://musicbrainz.org/ws/2"

  attr_reader :album

  def initialize(album)
    @album = album
  end

  def perform
    release_group = find_release_group
    return failure("Album was not found on MusicBrainz.") unless release_group

    release_group = fetch_release_group(release_group["id"]) || release_group
    releases = fetch_releases(release_group["id"])
    release = best_release(releases)
    wikipedia_data = wikipedia_data_for(release_group)

    result = {
      imported_tracks: 0,
      updated_tracks: 0,
      lyrics_found: 0,
      credits_imported: 0
    }

    ActiveRecord::Base.transaction do
      update_album!(release_group, release, wikipedia_data)
      import_tracks!(release, result) if release
    end

    result
  rescue => e
    Rails.logger.error "[AlbumEnrichmentService] Error enriching album #{album.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    failure(e.message)
  end

  private

  def failure(message)
    { error: message, imported_tracks: 0, updated_tracks: 0, lyrics_found: 0, credits_imported: 0 }
  end

  def find_release_group
    return fetch_release_group(album.musicbrainz_release_group_id) if album.musicbrainz_release_group_id.present?

    data = search_release_group
    groups = data&.fetch("release-groups", [])
    exact_match(groups) || groups.first
  end

  def search_release_group
    uri = URI("#{MUSICBRAINZ_URL}/release-group")
    query_parts = [
      %(releasegroup:"#{sanitize_query(album.title)}"),
      %(artist:"#{sanitize_query(album.artist.name)}")
    ]
    uri.query = URI.encode_www_form(query: query_parts.join(" AND "), fmt: "json", limit: 10)

    HttpClient.get_json(uri, headers)
  end

  def fetch_release_group(id)
    uri = URI("#{MUSICBRAINZ_URL}/release-group/#{id}")
    uri.query = URI.encode_www_form(inc: "url-rels artist-credits", fmt: "json")
    HttpClient.get_json(uri, headers)
  end

  def fetch_releases(release_group_id)
    uri = URI("#{MUSICBRAINZ_URL}/release")
    uri.query = URI.encode_www_form(
      "release-group": release_group_id,
      inc: "recordings artist-credits media labels",
      fmt: "json",
      limit: 100
    )
    HttpClient.get_json(uri, headers)&.fetch("releases", [])
  end

  def best_release(releases)
    releases.compact.max_by do |release|
      [
        release_track_count(release),
        release["date"].present? ? 1 : 0,
        release["status"] == "Official" ? 1 : 0
      ]
    end
  end

  def release_track_count(release)
    release.fetch("media", []).sum { |medium| medium.fetch("tracks", []).size }
  end

  def update_album!(release_group, release, wikipedia_data)
    album.musicbrainz_release_group_id ||= release_group["id"]
    album.title = release_group["title"] if album.title.blank? && release_group["title"].present?
    album.album_type = album_type_for(release_group) if album.respond_to?("#{album_type_for(release_group)}?")
    album.metadata_status = :imported if album.pending?

    date = release_group["first-release-date"].presence || release&.dig("date")
    album.original_release_date ||= parse_date(date)
    album.release_year ||= date.to_s[/\A\d{4}/]&.to_i

    if wikipedia_data
      album.wikidata_id ||= wikipedia_data[:wikidata_id]
      album.wikipedia_url ||= wikipedia_data[:url]
      album.summary = wikipedia_data[:summary] if wikipedia_data[:summary].present?
    end

    album.cover_url = cover_art_url(release_group["id"]) unless album.cover_image.attached?
    album.save!
  end

  def import_tracks!(release, result)
    track_rows_for(release).each do |row|
      track = find_or_build_track(row)
      was_new = track.new_record?

      track.title = row[:title]
      track.disc_number = row[:disc_number]
      track.track_number = row[:track_number]
      track.position = row[:position]
      track.duration = row[:duration] if row[:duration].present?
      track.musicbrainz_recording_id ||= row[:recording_id]

      if track.lyrics.blank?
        lyrics = fetch_lyrics(album.artist.name, row[:title], album.title)
        if lyrics[:lyrics].present?
          track.lyrics = lyrics[:lyrics]
          result[:lyrics_found] += 1
        end
      end

      track.save!
      result[was_new ? :imported_tracks : :updated_tracks] += 1
      result[:credits_imported] += import_track_credits!(track, row[:artist_credits])
    end
  end

  def track_rows_for(release)
    release.fetch("media", []).each_with_index.flat_map do |medium, disc_index|
      medium.fetch("tracks", []).each_with_index.map do |track, index|
        recording = track["recording"] || {}
        {
          disc_number: medium["position"].presence || disc_index + 1,
          track_number: track["number"].to_s[/\d+/]&.to_i || index + 1,
          position: track["number"].presence || track["position"].to_s,
          title: recording["title"].presence || track["title"],
          duration: formatted_duration(track["length"] || recording["length"]),
          recording_id: recording["id"],
          artist_credits: recording["artist-credit"] || track["artist-credit"] || release["artist-credit"] || []
        }
      end
    end.select { |row| row[:title].present? }
  end

  def find_or_build_track(row)
    if row[:recording_id].present?
      album.tracks.find_or_initialize_by(musicbrainz_recording_id: row[:recording_id])
    else
      album.tracks.find_or_initialize_by(disc_number: row[:disc_number], track_number: row[:track_number])
    end
  end

  def import_track_credits!(track, artist_credits)
    imported = 0

    artist_credits.each do |credit|
      name = credit.dig("artist", "name").presence || credit["name"]
      next if name.blank?

      record = track.track_credits.find_or_initialize_by(function: "Performer", name: clean_artist_name(name))
      next unless record.new_record?

      record.save!
      imported += 1
    end

    imported
  end

  def wikipedia_data_for(release_group)
    wikidata_id = wikidata_id_for(release_group)
    return nil if wikidata_id.blank?

    title = wikipedia_title(wikidata_id, "en")
    return { wikidata_id: wikidata_id } if title.blank?

    summary = wikipedia_summary(title)
    return { wikidata_id: wikidata_id } unless summary

    {
      wikidata_id: wikidata_id,
      summary: summary["extract"],
      url: summary["url"]
    }
  end

  def wikidata_id_for(release_group)
    url = release_group.fetch("relations", [])
      .find { |relation| relation["type"] == "wikidata" }
      &.dig("url", "resource")

    url.to_s.split("/").last.presence
  end

  def wikipedia_title(wikidata_id, language)
    uri = URI("https://www.wikidata.org/wiki/Special:EntityData/#{wikidata_id}.json")
    data = HttpClient.get_json(uri, headers)
    data&.dig("entities", wikidata_id, "sitelinks", "#{language}wiki", "title")
  rescue => e
    Rails.logger.warn "[AlbumEnrichmentService] Wikidata lookup failed for #{wikidata_id}: #{e.message}"
    nil
  end

  def wikipedia_summary(title)
    uri = URI("https://en.wikipedia.org/w/api.php")
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

    page = HttpClient.get_json(uri, headers).dig("query", "pages")&.values&.first
    return nil if page.nil? || page["missing"]

    { "extract" => page["extract"], "url" => page["fullurl"] }
  rescue => e
    Rails.logger.warn "[AlbumEnrichmentService] Wikipedia lookup failed for #{title}: #{e.message}"
    nil
  end

  def cover_art_url(release_group_id)
    "https://coverartarchive.org/release-group/#{release_group_id}/front"
  end

  def fetch_lyrics(artist, track, album_title)
    uri = URI("https://lrclib.net/api/get")
    uri.query = URI.encode_www_form(
      artist_name: artist,
      track_name: track,
      album_name: album_title
    )

    data = HttpClient.get_json(uri, headers)
    { found: data["plainLyrics"].present?, lyrics: data["plainLyrics"] }
  rescue => e
    Rails.logger.warn "[AlbumEnrichmentService] Lyrics lookup failed for #{track}: #{e.message}"
    { found: false, lyrics: nil }
  end

  def exact_match(groups)
    groups.find do |group|
      group["title"].to_s.casecmp(album.title.to_s).zero? &&
        group.dig("artist-credit", 0, "artist", "name").to_s.casecmp(album.artist.name.to_s).zero?
    end
  end

  def album_type_for(release_group)
    primary = release_group["primary-type"].to_s.downcase
    secondary = release_group.fetch("secondary-types", []).map { |type| type.to_s.downcase }

    return "soundtrack" if secondary.include?("soundtrack")
    return "compilation" if secondary.include?("compilation")
    return "live" if secondary.include?("live")
    return "box_set" if secondary.include?("box set")
    return "ep" if primary == "ep"
    return "single" if primary == "single"

    "studio"
  end

  def formatted_duration(milliseconds)
    return nil if milliseconds.blank?

    total_seconds = milliseconds.to_i / 1000
    minutes = total_seconds / 60
    seconds = total_seconds % 60
    format("%d:%02d", minutes, seconds)
  end

  def parse_date(value)
    return nil if value.blank?

    Date.parse(value)
  rescue ArgumentError
    nil
  end

  def clean_artist_name(name)
    name.to_s.gsub(/\s\(\d+\)\z/, "").strip
  end

  def sanitize_query(value)
    value.to_s.delete('"')
  end

  def headers
    { "User-Agent" => USER_AGENT }
  end
end
