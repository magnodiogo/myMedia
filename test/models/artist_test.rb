require "test_helper"
require "minitest/mock"
require "open-uri"

class ArtistTest < ActiveSupport::TestCase
  test "should download photo from URL before saving" do
    artist = Artist.new(name: "Test Artist")
    assert_not artist.photo.attached?

    URI.stub :open, ->(*_a) { File.open(Rails.root.join('db/seeds/images/dark_side_cover.png')) } do
      artist.photo_url = "https://example.com/artist.jpg"
      assert artist.save
      assert artist.photo.attached?
      
      path = ActiveStorage::Blob.service.path_for(artist.photo.key)
      assert File.exist?(path)
    end
  end
end
