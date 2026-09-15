require "test_helper"

class ArtistDiscographyImportJobTest < ActiveJob::TestCase
  test "loads artist discography" do
    artist = artists(:queen)
    called = false

    artist.define_singleton_method(:load_discography) do
      called = true
      { imported: 1, updated: 0, skipped: 0, error: nil }
    end

    ArtistDiscographyImportJob.perform_now(artist)

    assert called
  end
end
