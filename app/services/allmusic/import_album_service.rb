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

    attr_reader :record

    def initialize(record)
      @record = record
    end

    def call
      return skipped_result if record.allmusic_url.blank?

      html = download_html(record.allmusic_url)
      parsed = AlbumParser.call(html)

      ActiveRecord::Base.transaction do
        persist_metadata!(parsed)
        persist_credits!(parsed[:credits])
        record.update!(allmusic_imported_at: Time.current, allmusic_import_error: nil)
      end

      success_result(parsed)
    rescue => e
      record.update_columns(allmusic_import_error: e.message) if record&.persisted?
      Rails.logger.warn "[Allmusic::ImportAlbumService] Import failed for #{record.class.name} #{record&.id}: #{e.message}"
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

    def download_html(url)
      HttpClient.get(url)
    end

    def persist_metadata!(parsed)
      record.duration_seconds = duration_to_seconds(parsed[:duration]) if parsed[:duration].present?

      persist_named_links!(
        names: Array(parsed[:genre]).flat_map { |genre| split_names(genre) },
        model: MediaGenre,
        link_model: link_models[:genre],
        foreign_key: :media_genre
      )
      persist_named_links!(
        names: parsed[:styles],
        model: MediaStyle,
        link_model: link_models[:style],
        foreign_key: :media_style
      )
      persist_named_links!(
        names: Array(parsed[:recording_location]),
        model: RecordingLocation,
        link_model: link_models[:recording_location],
        foreign_key: :recording_location
      )

      sync_album_from_media!
      record.save! if record.changed?
    end

    def persist_credits!(credits)
      persisted_ids = []

      credits.each do |credit|
        credit_person = find_or_create_credit_person(credit[:person_name], credit[:allmusic_url])

        credit[:roles].each do |role|
          album_credit = find_existing_album_credit(credit_person, credit[:person_name], role)
          album_credit ||= record.album_credits.build

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

      record.album_credits.where(source: SOURCE).where.not(id: persisted_ids).destroy_all if persisted_ids.any?
    end

    def find_existing_album_credit(credit_person, person_name, role)
      record.album_credits
        .where(source: SOURCE, role: role)
        .where("LOWER(person_name) = ?", person_name.to_s.downcase)
        .first ||
        record.album_credits.find_by(source: SOURCE, role: role, credit_person: credit_person)
    end

    def find_or_create_credit_person(name, allmusic_url = nil)
      person = CreditPerson.where("LOWER(name) = ?", name.to_s.downcase).first || CreditPerson.create!(name: name)
      person.update!(allmusic_url: allmusic_url) if person.allmusic_url.blank? && allmusic_url.present?
      person
    end

    def persist_named_links!(names:, model:, link_model:, foreign_key:)
      records = names.map { |name| normalized_name(name) }.reject(&:blank?).uniq.map do |name|
        record = find_or_create_named_record(model, name)
        link_model.find_or_create_by!({ owner_key => self.record, foreign_key => record })
        record
      end

      link_model.where(owner_key => self.record).where.not("#{foreign_key}_id" => records.map(&:id)).destroy_all
    end

    def owner_key
      album_record? ? :album : :media
    end

    def link_models
      if album_record?
        { genre: AlbumGenreLink, style: AlbumStyleLink, recording_location: AlbumRecordingLocationLink }
      else
        { genre: MediaGenreLink, style: MediaStyleLink, recording_location: MediaRecordingLocationLink }
      end
    end

    def album_record?
      record.is_a?(Album)
    end

    def sync_album_from_media!
      return if album_record? || record.album.blank?

      record.album.allmusic_url ||= record.allmusic_url
      record.album.duration_seconds ||= record.duration_seconds
      record.album.save! if record.album.changed?
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
