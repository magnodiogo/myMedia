class ArtistAlbumDataImportJob < ApplicationJob
  queue_as :default

  def perform(artist)
    artist.albums.order(:release_year, :title).find_each do |album|
      AlbumEnrichmentService.new(album).perform
    rescue => e
      Rails.logger.error("[ArtistAlbumDataImportJob] Failed to load album data for album #{album.id}: #{e.message}")
    end
  end
end
