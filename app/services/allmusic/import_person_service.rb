require "net/http"
require "uri"
require "openssl"

module Allmusic
  class ImportPersonService
    USER_AGENT = "myMedia/1.0 (AllMusic person import)"
    MAX_REDIRECTS = 3

    def self.call(person)
      new(person).call
    end

    def initialize(person)
      @person = person
    end

    def call
      return skipped_result if @person.allmusic_url.blank?

      parsed = PersonParser.call(download_html(@person.allmusic_url))
      { success: true, skipped: false, error: nil, parsed: parsed }
    rescue => e
      Rails.logger.warn "[Allmusic::ImportPersonService] Import failed for credit person #{@person&.id}: #{e.message}"
      { success: false, skipped: false, error: e.message, parsed: empty_parsed_hash }
    end

    private

    def skipped_result
      { success: false, skipped: true, error: "AllMusic URL is blank", parsed: empty_parsed_hash }
    end

    def download_html(url, redirects: MAX_REDIRECTS)
      raise "Too many redirects while downloading AllMusic page" if redirects.negative?

      uri = URI.parse(url)
      response = http_response(uri)

      if response.is_a?(Net::HTTPRedirection)
        location = response["location"]
        raise "AllMusic redirect did not include a location" if location.blank?

        return download_html(URI.join(uri, location).to_s, redirects: redirects - 1)
      end

      raise "AllMusic request failed with HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      response.body.to_s
    end

    def http_response(uri)
      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 10
      http.read_timeout = 20
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE if http.use_ssl?

      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = USER_AGENT
      request["Accept"] = "text/html,application/xhtml+xml"
      http.request(request)
    end

    def empty_parsed_hash
      { name: nil, bio: nil, image_url: nil }
    end
  end
end
