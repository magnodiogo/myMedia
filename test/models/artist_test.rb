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

  test "should update bio from wikipedia" do
    artist = Artist.create!(name: "Pink Floyd")
    
    artist.stub :fetch_wikipedia_summary, { "extract" => "Pink Floyd were an English rock band formed in London in 1965." } do
      assert artist.update_bio_from_wikipedia
      assert_equal "Pink Floyd were an English rock band formed in London in 1965.", artist.reload.bio
    end
  end

  test "should update bio from pt wikipedia if en wikipedia is missing" do
    artist = Artist.create!(name: "Gilberto Gil")
    
    calls = []
    fetch_mock = ->(title, lang) {
      calls << lang
      lang == "pt" ? { "extract" => "Gilberto Gil é um cantor brasileiro." } : nil
    }
    
    artist.stub :fetch_wikipedia_summary, fetch_mock do
      assert artist.update_bio_from_wikipedia
      assert_equal "Gilberto Gil é um cantor brasileiro.", artist.reload.bio
      assert_equal ["en", "pt"], calls
    end
  end

  test "should update photo from wikipedia" do
    artist = Artist.create!(name: "Pink Floyd")
    
    artist.stub :fetch_wikipedia_image_url, "https://example.com/pink_floyd.jpg" do
      artist.stub :download_photo_from_url, true do
        assert artist.update_photo_from_wikipedia
        assert_equal "https://example.com/pink_floyd.jpg", artist.photo_url
      end
    end
  end

  test "should fallback to pt wikipedia for image if en is missing" do
    artist = Artist.create!(name: "Gilberto Gil")
    
    calls = []
    fetch_mock = ->(title, lang) {
      calls << lang
      lang == "pt" ? "https://example.com/gilberto_gil.jpg" : nil
    }
    
    artist.stub :fetch_wikipedia_image_url, fetch_mock do
      artist.stub :download_photo_from_url, true do
        assert artist.update_photo_from_wikipedia
        assert_equal "https://example.com/gilberto_gil.jpg", artist.photo_url
        assert_equal ["en", "pt"], calls
      end
    end
  end
end
