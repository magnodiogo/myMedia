require "nokogiri"
require "uri"

module Allmusic
  class PersonParser
    BIO_ENDINGS = /\A(Discography|Songs|Credits|Related|Moods and Themes|Album Highlights)\z/i

    def self.call(html)
      new(html).call
    end

    def initialize(html)
      @doc = Nokogiri::HTML(html)
      @lines = text_lines
    end

    def call
      {
        name: first_text("h1", ".artist-name", "[class*='artist-name']"),
        bio: extract_bio,
        image_url: extract_image_url
      }
    end

    private

    attr_reader :doc, :lines

    def extract_bio
      selector_bio = first_text(
        ".artist-biography",
        ".biography",
        ".bio",
        "[class*='biography']",
        "[class*='bio-text']"
      )
      return selector_bio if selector_bio.present?

      start_index = lines.index { |line| line.match?(/\ABiography\z/i) || line.match?(/\ABiography by .+/i) }
      return nil unless start_index

      bio_lines = lines[(start_index + 1)..].to_a.take_while { |line| !line.match?(BIO_ENDINGS) }
      normalized_text(bio_lines.join(" "))
    end

    def extract_image_url
      image = doc.at_css("meta[property='og:image']")&.[]("content").presence ||
        doc.at_css("meta[name='twitter:image']")&.[]("content").presence ||
        doc.at_css("img[class*='artist'], img[class*='photo'], img[class*='image']")&.[]("src").presence

      return nil if image.blank?

      URI.join("https://www.allmusic.com", image).to_s
    rescue URI::InvalidURIError
      nil
    end

    def first_text(*selectors)
      selectors.filter_map { |selector| normalized_text(doc.at_css(selector)&.text) }.first
    end

    def text_lines
      doc.text
        .split("\n")
        .map { |line| normalized_text(line) }
        .reject(&:blank?)
    end

    def normalized_text(value)
      value.to_s.squish.presence
    end
  end
end
