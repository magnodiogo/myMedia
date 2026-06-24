require "net/http"
require "uri"
require "openssl"

module Allmusic
  class ImportAlbumService
    SOURCE = "allmusic"
    USER_AGENT = "myMedia/1.0 (AllMusic album import)"
    MAX_REDIRECTS = 3

    def self.call(media)
      new(media).call
    end

    attr_reader :media

    def initialize(media)
      @media = media
    end

    def call
      return skipped_result if media.allmusic_url.blank?

      html = download_html(media.allmusic_url)
      parsed = AlbumParser.call(html)

      ActiveRecord::Base.transaction do
        persist_metadata!(parsed)
        persist_credits!(parsed[:credits])
        media.update!(allmusic_imported_at: Time.current, allmusic_import_error: nil)
      end

      success_result(parsed)
    rescue => e
      media.update_columns(allmusic_import_error: e.message) if media&.persisted?
      Rails.logger.warn "[Allmusic::ImportAlbumService] Import failed for media #{media&.id}: #{e.message}"
      failure_result(e.message)
    end

    private

    def skipped_result
      { success: false, skipped: true, error: "AllMusic URL is blank", parsed: empty_parsed_hash, credits: [] }
    end

    def success_result(parsed)
      {
        success: true,
        skipped: false,
        error: nil,
        parsed: parsed,
        credits: parsed[:credits]
      }
    end

    def failure_result(message)
      { success: false, skipped: false, error: message, parsed: empty_parsed_hash, credits: [] }
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

      unless response.is_a?(Net::HTTPSuccess)
        raise "AllMusic request failed with HTTP #{response.code}"
      end

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

    def persist_metadata!(parsed)
      media.duration_seconds = duration_to_seconds(parsed[:duration]) if parsed[:duration].present?

      persist_named_links!(
        names: Array(parsed[:genre]).flat_map { |genre| split_names(genre) },
        model: MediaGenre,
        link_model: MediaGenreLink,
        foreign_key: :media_genre
      )
      persist_named_links!(
        names: parsed[:styles],
        model: MediaStyle,
        link_model: MediaStyleLink,
        foreign_key: :media_style
      )
      persist_named_links!(
        names: Array(parsed[:recording_location]),
        model: RecordingLocation,
        link_model: MediaRecordingLocationLink,
        foreign_key: :recording_location
      )

      media.save! if media.changed?
    end

    def persist_credits!(credits)
      persisted_ids = []

      credits.each do |credit|
        credit_person = find_or_create_credit_person(credit[:person_name], credit[:allmusic_url])

        credit[:roles].each do |role|
          album_credit = find_existing_album_credit(credit_person, credit[:person_name], role)
          album_credit ||= media.album_credits.build

          album_credit.assign_attributes(
            credit_person: credit_person,
            person_name: credit[:person_name],
            role: role,
            source: SOURCE,
            credit_category: AlbumCredit.category_for_role(role),
            raw_data: { raw_text: credit[:raw_text], roles: credit[:roles] }
          )
          album_credit.save!
          persisted_ids << album_credit.id
        end
      end

      media.album_credits.where(source: SOURCE).where.not(id: persisted_ids).destroy_all if persisted_ids.any?
    end

    def find_existing_album_credit(credit_person, person_name, role)
      media.album_credits
        .where(source: SOURCE, role: role)
        .where("LOWER(person_name) = ?", person_name.to_s.downcase)
        .first ||
        media.album_credits.find_by(source: SOURCE, role: role, credit_person: credit_person)
    end

    def find_or_create_credit_person(name, allmusic_url = nil)
      person = CreditPerson.where("LOWER(name) = ?", name.to_s.downcase).first || CreditPerson.create!(name: name)
      person.update!(allmusic_url: allmusic_url) if person.allmusic_url.blank? && allmusic_url.present?
      person
    end

    def persist_named_links!(names:, model:, link_model:, foreign_key:)
      records = names.map { |name| normalized_name(name) }.reject(&:blank?).uniq.map do |name|
        record = find_or_create_named_record(model, name)
        link_model.find_or_create_by!({ media: media, foreign_key => record })
        record
      end

      link_model.where(media: media).where.not("#{foreign_key}_id" => records.map(&:id)).destroy_all
    end

    def find_or_create_named_record(model, name)
      model.where("LOWER(name) = ?", name.downcase).first || model.create!(name: name)
    end

    def split_names(value)
      value.to_s.split(/\s*,\s*/).map { |name| normalized_name(name) }.reject(&:blank?)
    end

    def duration_to_seconds(value)
      parts = value.to_s.split(":").map(&:to_i)
      return nil unless [2, 3].include?(parts.size)

      parts.reduce(0) { |total, part| (total * 60) + part }
    end

    def normalized_name(value)
      value.to_s.squish.presence
    end

    def empty_parsed_hash
      {
        title: nil,
        artist_name: nil,
        release_date: nil,
        duration: nil,
        genre: nil,
        styles: [],
        rating: nil,
        review_author: nil,
        review_text: nil,
        recording_location: nil,
        credits: []
      }
    end
  end
end
