require "nokogiri"

module Allmusic
  class AlbumParser
    KNOWN_ROLES = [
      "Accordion",
      "Art Direction",
      "Artwork",
      "Bass",
      "Bass (Electric)",
      "Composer",
      "Cover Painting",
      "Double Bass",
      "Drums",
      "Engineer",
      "Guitar",
      "Guitar (Acoustic)",
      "Guitar (Electric)",
      "Guitars",
      "Keyboards",
      "Layout",
      "Mandolin",
      "Mastering",
      "Mixing",
      "Organ",
      "Organ (Hammond)",
      "Percussion",
      "Photography",
      "Primary Artist",
      "Producer",
      "Tambourine",
      "Vocals",
      "Vocals (Background)"
    ].sort_by { |role| -role.length }.freeze

    def self.call(html)
      new(html).call
    end

    def initialize(html)
      @doc = Nokogiri::HTML(html)
      @lines = text_lines
      @artist_links_by_name = artist_links_by_name
    end

    def call
      {
        title: extract_album_title,
        artist_name: extract_artist_name,
        release_date: value_after_label("Release Date"),
        duration: value_after_label("Duration"),
        genre: value_after_label("Genre"),
        styles: split_list_value(value_after_label("Styles")),
        rating: extract_rating,
        review_author: extract_review_author,
        review_text: extract_review_text,
        recording_location: value_after_label("Recording Location"),
        credits: extract_credits
      }
    end

    private

    attr_reader :doc, :lines

    def extract_album_title
      heading = first_text("h1.album-title", ".album-title", "h1")
      artist = extract_artist_name
      title = heading
      title = title.sub(/\s*#{Regexp.escape(artist)}\z/, "") if title.present? && artist.present?
      title&.split(/\s+by\s+/i)&.first
    end

    def extract_artist_name
      first_text(
        "h1 a[href*='/artist/']",
        ".album-artist a",
        ".artist a",
        "[class*='artist'] a[href*='/artist/']",
        "a[href*='/artist/']"
      )
    end

    def extract_rating
      rating_text = first_text("[class*='allmusic-rating']", "[class*='rating']")
      return rating_text if rating_text.present? && rating_text.match?(/\d/)

      doc.css("img[alt], [title]").map { |node| node["alt"].presence || node["title"].presence }
        .compact
        .find { |value| value.match?(/rating/i) && value.match?(/\d/) }
    end

    def extract_review_author
      line = lines.find { |value| value.match?(/\A.+ Review by .+\z/) }
      line&.split(" Review by ", 2)&.last
    end

    def extract_review_text
      start_index = lines.index { |line| line.match?(/\A.+ Review by .+\z/) }
      return nil unless start_index

      end_index = lines[(start_index + 1)..]&.index { |line| line.match?(/\A.+ User Reviews\z|\A.+ Track List\z/) }
      review_lines = if end_index
        lines[(start_index + 1)...(start_index + 1 + end_index)]
      else
        lines[(start_index + 1)..]
      end

      normalized_text(review_lines.join(" "))
    end

    def extract_credits
      credits = structured_credits
      credits = text_credits if credits.empty?
      deduplicate_credits(credits)
    end

    def structured_credits
      rows = []

      doc.css("table[class*='credit'] tr, section[class*='credit'] tr, #credits tr").each do |row|
        cells = row.css("th, td").map { |cell| node_text(cell) }.compact
        next unless cells.size >= 2

        rows << build_credit(cells.first, cells[1..].join(", "), cells.join(" "))
      end

      doc.css(".credits li, #credits li, [class*='credit'] li, [class*='credit-row']").each do |node|
        person_name = node_text(node.at_css("a[href*='/artist/'], a"))
        next if person_name.blank?

        raw_text = node_text(node)
        role_text = normalized_text(raw_text.to_s.sub(person_name, ""))
        rows << build_credit(person_name, role_text, raw_text, artist_url_for(person_name))
      end

      rows.compact
    end

    def text_credits
      rows = []
      lines = credit_lines
      index = 0

      while index < lines.size
        line = lines[index]
        person_name, role_text = split_credit_line(line)

        if person_name.present? && role_text.present?
          rows << build_credit(person_name, role_text, line, artist_url_for(person_name))
          index += 1
          next
        end

        next_line = lines[index + 1]
        if next_line.present? && !credit_role_text?(line) && credit_role_text?(next_line)
          rows << build_credit(line, next_line, "#{line} #{next_line}", artist_url_for(line))
          index += 2
          next
        end

        index += 1
      end

      rows.compact
    end

    def credit_lines
      start_index = lines.index { |line| line.match?(/Credits\z/) }
      return [] unless start_index

      end_index = lines[(start_index + 1)..]&.index { |line| line.match?(/\AAdditional Releases\z|\ASimilar Albums\z|\AMoods and Themes\z/) }
      section = if end_index
        lines[(start_index + 1)...(start_index + 1 + end_index)]
      else
        lines[(start_index + 1)..]
      end
      apply_filters_index = section.index("Apply Filters")
      section = section[(apply_filters_index + 1)..] if apply_filters_index

      section.reject { |line| credit_control_line?(line) }
    end

    def credit_control_line?(line)
        line.blank? ||
        line.match?(/\AArtist Name/) ||
        line.match?(/\ACredit \(A-Z\)\z/) ||
        line.match?(/\ACredit \(Z-A\)\z/) ||
        line.match?(/\AAll Credits\z/) ||
        line.match?(/\AApply Filters\z/) ||
        line.match?(/\AAll Credits\s+/)
    end

    def split_credit_line(line)
      role_start = KNOWN_ROLES.filter_map do |role|
        index = line.index(role)
        next unless index&.positive?
        next unless line[index - 1].match?(/\s/)

        [index, role]
      end.min_by(&:first)

      return [nil, nil] unless role_start

      index = role_start.first
      [line[0...index].strip, line[index..].strip]
    end

    def build_credit(person_name, role_text, raw_text, allmusic_url = nil)
      person_name = normalized_text(person_name)
      return nil if person_name.blank? || person_name.match?(/\A\d+\z/)
      return nil unless credit_role_text?(role_text)

      roles = split_roles(role_text)
      return nil if roles.empty?

      {
        person_name: person_name,
        roles: roles,
        raw_text: normalized_text(raw_text),
        allmusic_url: allmusic_url
      }
    end

    def credit_role_text?(role_text)
      KNOWN_ROLES.any? { |role| normalized_text(role_text).to_s.include?(role) }
    end

    def split_roles(role_text)
      normalized_text(role_text).to_s
        .split(/\s*,\s*/)
        .map { |role| normalized_text(role) }
        .reject(&:blank?)
    end

    def deduplicate_credits(credits)
      seen = {}

      credits.select do |credit|
        key = [credit[:person_name], credit[:roles].join("|")]
        next false if seen[key]

        seen[key] = true
      end
    end

    def value_after_label(label)
      index = lines.index(label)
      return lines[(index + 1)..]&.find(&:present?) if index

      selectors = [
        "[data-label='#{label}']",
        "[aria-label='#{label}']"
      ]
      selector_value = first_text(*selectors)
      return selector_value if selector_value.present? && selector_value != label
    end

    def split_list_value(value)
      value.to_s.split(/\s*,\s*/).map { |item| normalized_text(item) }.reject(&:blank?)
    end

    def first_text(*selectors)
      selectors.filter_map { |selector| node_text(doc.at_css(selector)) }.first
    end

    def artist_links_by_name
      doc.css("a[href*='/artist/']").each_with_object({}) do |link, map|
        name = node_text(link)
        href = link["href"]
        next if name.blank? || href.blank?

        map[name] ||= absolute_allmusic_url(href)
      end
    end

    def artist_url_for(name)
      @artist_links_by_name[normalized_text(name)]
    end

    def absolute_allmusic_url(href)
      URI.join("https://www.allmusic.com", href).to_s
    rescue URI::InvalidURIError
      href
    end

    def text_lines
      doc.css("script, style, noscript").remove
      doc.text.split(/\n+/).map { |line| normalized_text(line) }.reject(&:blank?)
    end

    def node_text(node)
      normalized_text(node&.text)
    end

    def normalized_text(value)
      value.to_s.gsub(/\u00a0/, " ").squish.presence
    end
  end
end
