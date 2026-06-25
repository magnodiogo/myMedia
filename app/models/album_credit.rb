class AlbumCredit < ApplicationRecord
  COMPOSER_ROLES = [
    "Composer",
    "Songwriter",
    "Writer",
    "Written-By"
  ].freeze

  MUSICIAN_ROLES = [
    "Accordion",
    "Bass",
    "Bass (Electric)",
    "Double Bass",
    "Drums",
    "Guitar",
    "Guitar (Acoustic)",
    "Guitar (Electric)",
    "Guitars",
    "Keyboards",
    "Mandolin",
    "Organ",
    "Organ (Hammond)",
    "Percussion",
    "Primary Artist",
    "Tambourine",
    "Vocals",
    "Vocals (Background)"
  ].freeze

  CATEGORIES = %w[composer musician technical].freeze

  belongs_to :media, optional: true
  belongs_to :album, optional: true
  belongs_to :credit_person, optional: true

  validates :person_name, presence: true
  validates :role, presence: true
  validates :source, presence: true
  validates :credit_category, presence: true, inclusion: { in: CATEGORIES }
  validate :media_or_album_present

  before_validation :assign_person_name_from_credit_person
  before_validation :assign_credit_category

  scope :composers, -> { where(credit_category: "composer") }
  scope :musicians, -> { where(credit_category: "musician") }
  scope :technical_team, -> { where(credit_category: "technical") }

  def self.category_for_role(role)
    role_text = role.to_s.downcase
    return "composer" if COMPOSER_ROLES.any? { |known_role| role_text.include?(known_role.downcase) }
    return "musician" if MUSICIAN_ROLES.any? { |known_role| role_text.include?(known_role.downcase) }

    "technical"
  end

  private

  def assign_person_name_from_credit_person
    self.person_name ||= credit_person&.name
  end

  def assign_credit_category
    self.credit_category = self.class.category_for_role(role) if role.present?
  end

  def media_or_album_present
    return if media.present? || album.present?

    errors.add(:base, "Credit must belong to a media item or album")
  end
end
