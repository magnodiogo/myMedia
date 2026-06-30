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
    elsif wikipedia_url.blank?
      summary_data = fetch_wikipedia_summary_candidates
      if summary_data.present? && summary_data["fullurl"].present?
        self.wikipedia_url = summary_data["fullurl"]
        result[:wikipedia_bio] = true
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
      prop: "extracts|info",
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
end
