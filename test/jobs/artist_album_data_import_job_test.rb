require "test_helper"

class ArtistAlbumDataImportJobTest < ActiveJob::TestCase
  test "loads album data for every artist album" do
    artist = artists(:queen)
    albums = artist.albums.to_a
    loaded_album_ids = []

    fake_service = Struct.new(:album, :loaded_album_ids) do
      def perform
        loaded_album_ids << album.id
        { imported_tracks: 0, updated_tracks: 0, lyrics_found: 0 }
      end
    end

    original_new = AlbumEnrichmentService.method(:new)
    AlbumEnrichmentService.define_singleton_method(:new) do |album|
      fake_service.new(album, loaded_album_ids)
    end

    ArtistAlbumDataImportJob.perform_now(artist)

    assert_equal albums.map(&:id).sort, loaded_album_ids.sort
  ensure
    AlbumEnrichmentService.define_singleton_method(:new) do |*args|
      original_new.call(*args)
    end
  end
end
