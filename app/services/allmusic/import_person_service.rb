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

    def download_html(url)
      HttpClient.get(url)
    end

    def empty_parsed_hash
      { name: nil, bio: nil, image_url: nil }
    end
  end
end
