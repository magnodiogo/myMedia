require "net/http"
require "uri"
require "openssl"
require "nokogiri"

module Allmusic
  class AlbumSearchService
    USER_AGENT = "myMedia/1.0 (AllMusic album search)"

    def self.call(album)
      new(album).call
    end

    def initialize(album)
      @album = album
    end

    def call
      query = [@album.artist&.name, @album.title].compact_blank.join(" ")
      return nil if query.blank?

      html = download_html(search_url(query))
      parse_album_url(html)
    rescue => e
      Rails.logger.warn "[Allmusic::AlbumSearchService] Search failed for album #{@album&.id}: #{e.message}"
      nil
    end

    private

    def search_url(query)
      encoded_query = URI.encode_www_form_component(query).gsub("+", "%20")
      "https://www.allmusic.com/search/albums/#{encoded_query}"
    end

    def download_html(url)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 10
      http.read_timeout = 20
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE if http.use_ssl?

      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = USER_AGENT
      request["Accept"] = "text/html,application/xhtml+xml"

      response = http.request(request)
      return response.body.to_s if response.is_a?(Net::HTTPSuccess)

      nil
    end

    def parse_album_url(html)
      return nil if html.blank?

      doc = Nokogiri::HTML(html)
      links = doc.css("a[href*='/album/']")
      preferred_link = links.find { |link| matching_album_link?(link) } || links.first
      href = preferred_link&.[]("href").presence
      return nil if href.blank?

      URI.join("https://www.allmusic.com", href).to_s
    rescue URI::InvalidURIError
      nil
    end

    def matching_album_link?(link)
      text = link.text.to_s.squish.downcase
      title = @album.title.to_s.squish.downcase
      text.present? && title.present? && (text == title || text.include?(title))
    end
  end
end
