require "open-uri"
require "net/http"
require "json"
require "cgi"

class CreditPerson < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged

  has_many :album_credits, dependent: :restrict_with_error
  has_many :media, through: :album_credits
  has_one_attached :photo

  attr_accessor :photo_url

  before_save :download_photo_from_url, if: -> { photo_url.present? }
  after_create_commit :enqueue_metadata_import

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  def to_s
    name
  end

  def birth_summary
    life_event_summary("Born", birth_date, birth_place, age)
  end

  def death_summary
    life_event_summary("Died", death_date, death_place, age_at_death)
  end

  def age
    return nil if birth_date.blank? || death_date.present?

    age_on(Date.current)
  end

  def age_at_death
    return nil if birth_date.blank? || death_date.blank?

    age_on(death_date)
  end

  def update_bio_from_wikipedia
    summary_data = fetch_wikipedia_summary_candidates(require_extract: true)
    return false if summary_data.blank? || summary_data["extract"].blank?

    self.bio = summary_data["extract"]
    self.wikipedia_url = summary_data["fullurl"] if summary_data["fullurl"].present?
    save
  end

  def update_photo_from_wikipedia
    image_url = fetch_wikipedia_image_url_candidates
    return false if image_url.blank?

    self.photo_url = image_url
    save
  end

  def load_external_data
    result = {
      allmusic: false,
      wikipedia_bio: false,
      wikipedia_photo: false,
      wikidata: false,
      bio: false,
      photo: false,
      errors: []
    }

    summary_data = fetch_wikipedia_summary_candidates(require_extract: true)
    if summary_data.present?
      self.bio = summary_data["extract"]
      self.wikipedia_url = summary_data["fullurl"] if summary_data["fullurl"].present?
      result[:wikipedia_bio] = true
      result[:bio] = true

      wikibase_item = summary_data.dig("pageprops", "wikibase_item")
      if wikibase_item.present?
        fetch_and_populate_wikidata_details(wikibase_item)
        result[:wikidata] = true if birth_date_changed? || birth_place_changed? || death_date_changed? || death_place_changed?
      end
    elsif wikipedia_url.blank?
      summary_data = fetch_wikipedia_summary_candidates
      if summary_data.present? && summary_data["fullurl"].present?
        self.wikipedia_url = summary_data["fullurl"]
        result[:wikipedia_bio] = true

        wikibase_item = summary_data.dig("pageprops", "wikibase_item")
        if wikibase_item.present?
          fetch_and_populate_wikidata_details(wikibase_item)
          result[:wikidata] = true if birth_date_changed? || birth_place_changed? || death_date_changed? || death_place_changed?
        end
      end
    end

    allmusic_result = Allmusic::ImportPersonService.call(self)
    if allmusic_result[:success]
      parsed = allmusic_result[:parsed] || {}

      if bio.blank? && parsed[:bio].present?
        self.bio = parsed[:bio]
        result[:allmusic] = true
        result[:bio] = true
      end

      if parsed[:image_url].present? && !photo.attached?
        self.photo_url = parsed[:image_url]
        result[:allmusic] = true
        result[:photo] = true
      end
    elsif !allmusic_result[:skipped]
      result[:errors] << allmusic_result[:error]
    end

    unless photo.attached? || photo_url.present?
      image_url = fetch_wikipedia_image_url_candidates
      if image_url.present?
        self.photo_url = image_url
        result[:wikipedia_photo] = true
        result[:photo] = true
      end
    end

    save if changed? || photo_url.present?
    result
  end

  private

  def life_event_summary(label, date, place, age_value)
    details = [formatted_life_date(date), place.presence].compact.join(", ")
    return nil if details.blank?

    summary = "#{label}: #{details}"
    summary += " (#{age_value})" if age_value.present? 
    summary
  end

  def formatted_life_date(date)
    date&.strftime("%B %-d, %Y")
  end

  def age_on(date)
    years = date.year - birth_date.year
    had_birthday = date.month > birth_date.month || (date.month == birth_date.month && date.day >= birth_date.day)
    years -= 1 unless had_birthday
    years
  end

  def fetch_wikipedia_summary_candidates(require_extract: false)
    wikipedia_title_candidates.each do |candidate|
      summary = fetch_wikipedia_summary(candidate[:title], candidate[:language])
      next if summary.blank?
      next if require_extract && summary["extract"].blank?

      return summary
    end

    nil
  end

  def fetch_wikipedia_image_url_candidates
    wikipedia_title_candidates.each do |candidate|
      image_url = fetch_wikipedia_image_url(candidate[:title], candidate[:language])
      return image_url if image_url.present?
    end

    nil
  end

  def wikipedia_title_candidates
    candidates = []
    url_candidate = wikipedia_title_candidate_from_url
    candidates << url_candidate if url_candidate.present?
    candidates << { title: name, language: "en" }
    candidates << { title: name, language: "pt" }
    candidates.uniq
  end

  def wikipedia_title_candidate_from_url
    return nil if wikipedia_url.blank?

    uri = URI.parse(wikipedia_url)
    language = uri.host.to_s[/\A([a-z-]+)\.wikipedia\.org\z/, 1].presence || "en"
    title = uri.path.to_s.sub(%r{\A/wiki/}, "")
    title = CGI.unescape(title).tr("_", " ").presence
    return nil if title.blank?

    { title: title, language: language }
  rescue URI::InvalidURIError
    nil
  end

  def fetch_wikipedia_summary(title, language)
    uri = URI("https://#{language}.wikipedia.org/w/api.php")
    uri.query = URI.encode_www_form(
      action: "query",
      prop: "extracts|info|pageprops",
      exintro: true,
      explaintext: true,
      inprop: "url",
      titles: title,
      redirects: 1,
      format: "json"
    )

    response = http_get(uri)
    return nil unless response.code == "200"

    page = JSON.parse(response.body).dig("query", "pages")&.values&.first
    return nil if page.nil? || page["missing"]

    page
  rescue => e
    Rails.logger.error "Wikipedia #{language} fetch error for credit person #{title}: #{e.message}"
    nil
  end

  def fetch_and_populate_wikidata_details(qid)
    return if qid.blank?

    uri = URI("https://www.wikidata.org/wiki/Special:EntityData/#{qid}.json")
    response = http_get(uri)
    return unless response.code == "200"

    data = JSON.parse(response.body)
    entity = data.dig("entities", qid)
    return unless entity

    # Extract birth date (P569)
    if birth_date.blank?
      b_date_str = entity.dig("claims", "P569")&.first&.dig("mainsnak", "datavalue", "value", "time")
      if b_date_str.present? && b_date_str =~ /\A\+?(\d{4}-\d{2}-\d{2})/
        self.birth_date = Date.parse($1) rescue nil
      end
    end

    # Extract death date (P570)
    if death_date.blank?
      d_date_str = entity.dig("claims", "P570")&.first&.dig("mainsnak", "datavalue", "value", "time")
      if d_date_str.present? && d_date_str =~ /\A\+?(\d{4}-\d{2}-\d{2})/
        self.death_date = Date.parse($1) rescue nil
      end
    end

    # Extract birth place QID (P19) and death place QID (P20)
    b_place_qid = entity.dig("claims", "P19")&.first&.dig("mainsnak", "datavalue", "value", "id")
    d_place_qid = entity.dig("claims", "P20")&.first&.dig("mainsnak", "datavalue", "value", "id")

    if b_place_qid.present? && birth_place.blank?
      self.birth_place = resolve_wikidata_place_name(b_place_qid)
    end

    if d_place_qid.present? && death_place.blank?
      self.death_place = resolve_wikidata_place_name(d_place_qid)
    end
  rescue => e
    Rails.logger.error "Wikidata fetch error for QID #{qid}: #{e.message}"
  end

  def resolve_wikidata_place_name(place_qid)
    return nil if place_qid.blank?

    place_data = fetch_wikidata_entity(place_qid)
    return nil unless place_data

    place_label = get_wikidata_label_from_entity(place_data)
    return nil if place_label.blank?

    p131_qid = place_data.dig("claims", "P131")&.first&.dig("mainsnak", "datavalue", "value", "id")
    p17_qid = place_data.dig("claims", "P17")&.first&.dig("mainsnak", "datavalue", "value", "id")

    parent_label = nil
    grandparent_label = nil
    if p131_qid.present?
      parent_data = fetch_wikidata_entity(p131_qid)
      if parent_data
        parent_label = get_wikidata_label_from_entity(parent_data)
        
        gp131_qid = parent_data.dig("claims", "P131")&.first&.dig("mainsnak", "datavalue", "value", "id")
        if gp131_qid.present? && gp131_qid != p17_qid
          gp_data = fetch_wikidata_entity(gp131_qid)
          if gp_data
            grandparent_label = get_wikidata_label_from_entity(gp_data)
          end
        end
      end
    end

    country_label = nil
    if p17_qid.present?
      country_data = fetch_wikidata_entity(p17_qid)
      if country_data
        country_label = get_wikidata_label_from_entity(country_data)
      end
    end

    parts = [place_label]
    [parent_label, grandparent_label].each do |lbl|
      next if lbl.blank?
      next if lbl.downcase =~ /county|condado|district|distrito|parish/
      next if parts.include?(lbl)
      parts << lbl
    end

    if country_label.present?
      if country_label =~ /\A(United States( of America)?|Estados Unidos( da América)?)\z/i
        country_label = "U.S."
      end
      parts << country_label unless parts.include?(country_label)
    end

    parts.join(", ")
  rescue => e
    Rails.logger.error "Error resolving place name for QID #{place_qid}: #{e.message}"
    nil
  end

  def fetch_wikidata_entity(qid)
    return nil if qid.blank?

    uri = URI("https://www.wikidata.org/wiki/Special:EntityData/#{qid}.json")
    response = http_get(uri)
    return nil unless response.code == "200"

    data = JSON.parse(response.body)
    data.dig("entities", qid)
  rescue => e
    Rails.logger.error "Error fetching Wikidata entity #{qid}: #{e.message}"
    nil
  end

  def get_wikidata_label_from_entity(entity_data)
    entity_data.dig("labels", "en", "value") || entity_data.dig("labels", "pt", "value")
  end

  def fetch_wikipedia_image_url(title, language)
    uri = URI("https://#{language}.wikipedia.org/w/api.php")
    uri.query = URI.encode_www_form(
      action: "query",
      prop: "pageimages",
      piprop: "original",
      titles: title,
      redirects: 1,
      format: "json"
    )

    response = http_get(uri)
    return nil unless response.code == "200"

    page = JSON.parse(response.body).dig("query", "pages")&.values&.first
    return nil if page.nil? || page["missing"]

    page.dig("original", "source")
  rescue => e
    Rails.logger.error "Wikipedia #{language} image fetch error for credit person #{title}: #{e.message}"
    nil
  end

  def http_get(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE if http.use_ssl?

    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "myMedia/1.0"
    http.request(request)
  end

  def download_photo_from_url
    url = photo_url
    self.photo_url = nil

    file = URI.open(url, "User-Agent" => "myMedia/1.0", ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE, open_timeout: 5, read_timeout: 5)
    temp_path = Rails.root.join("tmp", "credit-person-#{SecureRandom.hex(8)}.jpg")
    File.open(temp_path, "wb") { |f| f.write(file.read) }

    system("mogrify -resize '600x600>' -strip #{temp_path}")

    photo.attach(io: File.open(temp_path), filename: "credit-person-#{SecureRandom.hex(8)}.jpg", content_type: "image/jpeg")
    File.delete(temp_path) if File.exist?(temp_path)
  rescue => e
    Rails.logger.error("Failed to download credit person photo from URL #{url}: #{e.message}")
  end

  private

  def enqueue_metadata_import
    CreditPersonMetadataJob.perform_later(self)
  end
end
