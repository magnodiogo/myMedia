class MediaType < ApplicationRecord
  has_many :media, class_name: "Media", dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  def self.for_release_format(format)
    normalized = format.to_s.strip
    return first if normalized.blank?

    aliases = {
      "cd" => ["CD RedBook", "CD"],
      "lp" => ["Vinyl LP", "LP"],
      "12 inch vinyl single" => ["Vinyl LP", "12 inch Vinyl Single"],
      "cassette" => ["Cassette Tape", "Cassette"],
      "digital" => ["Digital"],
      "dvd" => ["DVD Audio", "DVD"]
    }

    candidates = aliases.fetch(normalized.downcase, [normalized])
    candidates.each do |candidate|
      media_type = where("LOWER(name) = ?", candidate.downcase).first
      return media_type if media_type
    end

    where("LOWER(name) LIKE ?", "%#{sanitize_sql_like(normalized.downcase)}%").first ||
      create!(name: candidates.first)
  end
end
