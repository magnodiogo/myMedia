class ArtistDiscographyImportJob < ApplicationJob
  queue_as :default

  def perform(artist)
    result = artist.load_discography
    if result[:error].present?
      Rails.logger.error("[ArtistDiscographyImportJob] Failed to load discography for artist #{artist.id}: #{result[:error]}")
    end
  rescue => e
    Rails.logger.error("[ArtistDiscographyImportJob] Failed to load discography for artist #{artist.id}: #{e.message}")
  end
end
