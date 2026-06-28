class ArtistEra < ApplicationRecord
  belongs_to :artist

  validates :artist, presence: true
  validates :name, presence: true
  validate :starts_on_before_or_equal_to_ends_on

  scope :ordered, -> { order(:position, :starts_on, :name) }

  def includes_media?(medium)
    return false unless medium&.artist_id == artist_id
    return true if starts_on.blank? && ends_on.blank?

    release_year = medium.release_year
    return false if release_year.blank?

    (starts_on.blank? || release_year >= starts_on.year) &&
      (ends_on.blank? || release_year <= ends_on.year)
  end

  def media_scope
    scope = artist.media
    scope = scope.where("release_year >= ?", starts_on.year) if starts_on.present?
    scope = scope.where("release_year <= ?", ends_on.year) if ends_on.present?
    scope
  end

  private

  def starts_on_before_or_equal_to_ends_on
    return if starts_on.blank? || ends_on.blank?
    return if starts_on <= ends_on

    errors.add(:starts_on, "must be before or equal to ends on")
  end
end
