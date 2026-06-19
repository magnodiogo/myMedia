require "net/http"
require "json"
require "uri"
require "openssl"

class MediaEnrichmentService
  class HttpClient
    def self.get_json(uri, headers = {})
      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE if http.use_ssl?

      request = Net::HTTP::Get.new(uri)
      headers.each { |k, v| request[k] = v }

      response = http.request(request)

      raise "Erro HTTP #{response.code}: #{response.body}" unless response.code.to_i.between?(200, 299)

      JSON.parse(response.body)
    end
  end

  class DiscogsClient
    BASE_URL = "https://api.discogs.com"

    def initialize(token:)
      @token = token
    end

    def search_by_barcode(barcode)
      uri = URI("#{BASE_URL}/database/search")
      uri.query = URI.encode_www_form(barcode: barcode, type: "release")
      HttpClient.get_json(uri, headers)
    end

    def release(id)
      uri = URI("#{BASE_URL}/releases/#{id}")
      HttpClient.get_json(uri, headers)
    end

    def artist(id)
      uri = URI("#{BASE_URL}/artists/#{id}")
      HttpClient.get_json(uri, headers)
    rescue => e
      Rails.logger.error "Erro ao buscar artista no Discogs: #{e.message}"
      nil
    end

    private

    def headers
      {
        "Authorization" => "Discogs Token #{@token}",
        "User-Agent" => "ColecaoCDs/1.0"
      }
    end
  end

  class MusicBrainzClient
    BASE_URL = "https://musicbrainz.org/ws/2"

    def search_by_barcode(barcode)
      uri = URI("#{BASE_URL}/release/")
      uri.query = URI.encode_www_form(query: "barcode:#{barcode}", fmt: "json")
      HttpClient.get_json(uri, headers)
    rescue => e
      Rails.logger.error "Erro MusicBrainz: #{e.message}"
      nil
    end

    def release_group(id)
      uri = URI("#{BASE_URL}/release-group/#{id}")
      uri.query = URI.encode_www_form(inc: "url-rels artist-credits", fmt: "json")
      HttpClient.get_json(uri, headers)
    rescue => e
      Rails.logger.error "Erro Release Group MusicBrainz: #{e.message}"
      nil
    end

    def artist(id)
      uri = URI("#{BASE_URL}/artist/#{id}")
      uri.query = URI.encode_www_form(inc: "url-rels", fmt: "json")
      HttpClient.get_json(uri, headers)
    rescue => e
      Rails.logger.error "Erro Artist MusicBrainz: #{e.message}"
      nil
    end

    private

    def headers
      {
        "User-Agent" => "ColecaoCDs/1.0 (seu-email@exemplo.com)"
      }
    end
  end

  class WikidataClient
    def entity(qid)
      uri = URI("https://www.wikidata.org/wiki/Special:EntityData/#{qid}.json")
      HttpClient.get_json(uri, { "User-Agent" => "ColecaoCDs/1.0" })
    rescue => e
      Rails.logger.error "Erro Wikidata: #{e.message}"
      nil
    end

    def wikipedia_title(qid, language:)
      data = entity(qid)
      entity = data&.dig("entities", qid)
      entity&.dig("sitelinks", "#{language}wiki", "title")
    end
  end

  class WikipediaClient
    def initialize(language:)
      @language = language
    end

    def summary(title)
      uri = URI("https://#{@language}.wikipedia.org/w/api.php")
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

      data = HttpClient.get_json(uri, headers)
      page = data.dig("query", "pages")&.values&.first
      return nil if page.nil? || page["missing"]

      {
        "title" => page["title"],
        "extract" => page["extract"],
        "url" => page["fullurl"]
      }
    rescue => e
      Rails.logger.error "Erro Wikipedia #{@language}: #{e.message}"
      nil
    end

    private

    def headers
      { "User-Agent" => "ColecaoCDs/1.0" }
    end
  end

  attr_reader :media

  def initialize(media)
    @media = media
  end

  def perform
    barcode = media.barcode.to_s.gsub(/[-\s]/, "")
    return if barcode.blank?

    token = ENV["DISCOGS_TOKEN"] || "TPfEJXlWcimuwWmFvvENlMGtyHbvJtqhsSzbpjuX"

    discogs = DiscogsClient.new(token: token)
    musicbrainz = MusicBrainzClient.new
    wikidata = WikidataClient.new
    wikipedia_pt = WikipediaClient.new(language: "pt")
    wikipedia_en = WikipediaClient.new(language: "en")

    begin
      # 1. Query Discogs
      discogs_result = discogs.search_by_barcode(barcode)
      return if discogs_result["results"].nil? || discogs_result["results"].empty?

      item = discogs_result["results"].first
      detalhes = discogs.release(item["id"])

      artist_name = clean_artist_name(detalhes["artists"]&.first&.dig("name"))
      album_title = clean_album_title(detalhes["title"])

      artist_id = detalhes["artists"]&.first&.dig("id")
      artist_photo_url = nil
      if artist_id
        artist_details = discogs.artist(artist_id)
        artist_photo_url = artist_details&.dig("images")&.first&.dig("uri") if artist_details
      end

      # 2. Query MusicBrainz
      mb_result = musicbrainz.search_by_barcode(barcode)
      mb_release = mb_result&.dig("releases", 0)

      album_wikidata_qid = nil
      artist_mb_id = nil

      if mb_release
        artist_mb_id = mb_release.dig("artist-credit", 0, "artist", "id")
        release_group_id = mb_release.dig("release-group", "id")

        if release_group_id
          rg = musicbrainz.release_group(release_group_id)
          if rg
            wikidata_url = rg["relations"]
              &.find { |rel| rel["type"] == "wikidata" }
              &.dig("url", "resource")

            if wikidata_url
              album_wikidata_qid = extract_wikidata_id(wikidata_url)
            end
          end
        end
      end

      # 3. Get Album Wikipedia Summary
      album_wiki = nil
      if album_wikidata_qid
        album_wiki = get_wikipedia_from_wikidata(wikidata, wikipedia_pt, wikipedia_en, album_wikidata_qid)
      end

      # 4. Get Artist Wikipedia Summary
      artist_wiki = nil
      if artist_mb_id
        mb_artist = musicbrainz.artist(artist_mb_id)
        artist_wikidata_url = mb_artist&.dig("relations")
          &.find { |rel| rel["type"] == "wikidata" }
          &.dig("url", "resource")

        if artist_wikidata_url
          artist_wikidata_qid = extract_wikidata_id(artist_wikidata_url)
          artist_wiki = get_wikipedia_from_wikidata(wikidata, wikipedia_pt, wikipedia_en, artist_wikidata_qid)
        end
      end

      # 5. Save to Database
      ActiveRecord::Base.connection_pool.with_connection do
        media.reload # Ensure we have the latest state

        # Set/update attributes
        media.title = album_title if media.title.blank?
        media.release_year = detalhes["year"] if media.release_year.blank?
        media.catalog_number = detalhes["labels"]&.first&.dig("catno") if media.catalog_number.blank?
        media.cover_url = detalhes["images"]&.first&.dig("uri") if media.cover_image.blank? && detalhes["images"]&.any?

        if album_wiki && album_wiki[:data] && album_wiki[:data]["extract"]
          media.info = album_wiki[:data]["extract"]
        end

        # Find or create artist and update bio and photo
        artist = media.artist || Artist.find_or_initialize_by(name: artist_name)
        if artist_wiki && artist_wiki[:data] && artist_wiki[:data]["extract"]
          artist.bio = artist_wiki[:data]["extract"]
        end
        if artist_photo_url.present? && !artist.photo.attached?
          artist.photo_url = artist_photo_url
        end
        artist.save!
        
        media.artist = artist
        media.save!

        # Recreate tracks
        if detalhes["tracklist"]&.any?
          media.tracks.destroy_all

          tracks_to_save = detalhes["tracklist"].select { |t| t["type_"].nil? || t["type_"] == "track" || t["type_"].empty? }
          tracks_to_save.each_with_index do |track_data, index|
            track_number = index + 1
            duration = track_data["duration"].to_s.strip
            duration = nil unless duration =~ /\A\d+:\d{2}\z/

            # Fetch lyrics for this track
            lyrics_res = fetch_lyrics(artist.name, track_data["title"], media.title)
            lyrics = lyrics_res[:lyrics]

            media.tracks.create!(
              title: track_data["title"],
              track_number: track_number,
              position: track_data["position"],
              duration: duration,
              lyrics: lyrics
            )

            sleep 0.5 # be polite to API
          end
        end
      end

    rescue => e
      Rails.logger.error "[MediaEnrichmentService] Error enriching media #{media.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end

  private

  def clean_artist_name(name)
    name.to_s.gsub(/\s\(\d+\)$/, "").strip
  end

  def clean_album_title(title)
    title = title.to_s.strip
    title = title.split(" - ", 2).last if title.include?(" - ")
    title
  end

  def extract_wikidata_id(url)
    url.to_s.split("/").last
  end

  def get_wikipedia_from_wikidata(wikidata, wikipedia_pt, wikipedia_en, qid)
    title_pt = wikidata.wikipedia_title(qid, language: "pt")
    sleep 0.2
    title_en = wikidata.wikipedia_title(qid, language: "en")

    data = nil
    language = nil
    title_used = nil

    if title_pt
      data = wikipedia_pt.summary(title_pt)
      language = "pt" if data
      title_used = title_pt if data
    end

    sleep 0.2

    if data.nil? && title_en
      data = wikipedia_en.summary(title_en)
      language = "en" if data
      title_used = title_en if data
    end

    {
      title_pt: title_pt,
      title_en: title_en,
      title_used: title_used,
      language: language,
      data: data
    }
  end

  def fetch_lyrics(artist, track, album = nil)
    headers = { "User-Agent" => "CDCollection/1.0" }
    
    # Attempt 1: Exact search
    begin
      uri = URI("https://lrclib.net/api/get")
      params = {
        artist_name: artist,
        track_name: track
      }
      params[:album_name] = album if album.present?
      uri.query = URI.encode_www_form(params)

      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE if http.use_ssl?
      
      request = Net::HTTP::Get.new(uri)
      headers.each { |k, v| request[k] = v }
      
      response = http.request(request)
      if response.code == "200"
        data = JSON.parse(response.body)
        lyrics = data["plainLyrics"]
        return { found: true, lyrics: lyrics } if lyrics.present?
      end
    rescue => e
      Rails.logger.warn "[MediaEnrichmentService] LRCLib exact fetch failed for #{track}: #{e.message}"
    end

    # Attempt 2: Search
    begin
      uri = URI("https://lrclib.net/api/search")
      uri.query = URI.encode_www_form(
        artist_name: artist,
        track_name: track
      )

      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE if http.use_ssl?
      
      request = Net::HTTP::Get.new(uri)
      headers.each { |k, v| request[k] = v }
      
      response = http.request(request)
      if response.code == "200"
        results = JSON.parse(response.body)
        item = results.find { |r| r["plainLyrics"].present? }
        return { found: true, lyrics: item["plainLyrics"] } if item
      end
    rescue => e
      Rails.logger.warn "[MediaEnrichmentService] LRCLib search failed for #{track}: #{e.message}"
    end

    { found: false, lyrics: nil }
  end
end
