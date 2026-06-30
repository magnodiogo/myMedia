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

  test "should load discography from musicbrainz release groups" do
    artist = Artist.create!(name: "Discography Test Artist")

    artist.define_singleton_method(:fetch_musicbrainz_artist) do
      { "id" => "artist-mbid", "name" => name }
    end

    artist.define_singleton_method(:fetch_musicbrainz_release_groups) do |_musicbrainz_artist_id|
      [
        {
          "id" => "album-mbid",
          "title" => "Imported Studio Album",
          "primary-type" => "Album",
          "secondary-types" => [],
          "first-release-date" => "1975-09-12"
        },
        {
          "id" => "live-mbid",
          "title" => "Imported Live Album",
          "primary-type" => "Album",
          "secondary-types" => ["Live"],
          "first-release-date" => "1977"
        }
      ]
    end

    artist.define_singleton_method(:cover_art_archive_url) { |_musicbrainz_release_group_id| nil }

    assert_difference("Album.count", 2) do
      result = artist.load_discography

      assert_equal 2, result[:imported]
      assert_equal 0, result[:updated]
      assert_equal 0, result[:skipped]
      assert_nil result[:error]
    end

    studio_album = artist.albums.find_by!(musicbrainz_release_group_id: "album-mbid")
    live_album = artist.albums.find_by!(musicbrainz_release_group_id: "live-mbid")

    assert_equal "Imported Studio Album", studio_album.title
    assert_equal "studio", studio_album.album_type
    assert_equal "imported", studio_album.metadata_status
    assert_equal 1975, studio_album.release_year
    assert_equal Date.new(1975, 9, 12), studio_album.original_release_date

    assert_equal "live", live_album.album_type
    assert_equal 1977, live_album.release_year
    assert_nil live_album.original_release_date
  end

  test "should report error when discography artist is not found" do
    artist = Artist.create!(name: "Unknown Discography Artist")
    artist.define_singleton_method(:fetch_musicbrainz_artist) { nil }

    result = artist.load_discography

    assert_equal 0, result[:imported]
    assert_equal "Artist not found on MusicBrainz.", result[:error]
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

  test "should be able to attach banner to artist" do
    artist = Artist.new(name: "Banner Test Artist")
    assert_not artist.banner.attached?

    artist.banner.attach(
      io: File.open(Rails.root.join("db/seeds/images/dark_side_cover.png")),
      filename: "dark_side_cover.png",
      content_type: "image/png"
    )
    assert artist.save
    assert artist.banner.attached?
  end

  test "should update banner from wikipedia" do
    artist = Artist.create!(name: "Pink Floyd")

    artist.stub :fetch_wikipedia_image_url, "https://example.com/pink_floyd_banner.jpg" do
      URI.stub :open, ->(*_a) { File.open(Rails.root.join("db/seeds/images/dark_side_cover.png")) } do
        assert artist.update_banner_from_wikipedia
        assert artist.banner.attached?
      end
    end
  end

  test "should fallback to pt wikipedia for banner if en is missing" do
    artist = Artist.create!(name: "Gilberto Gil")

    calls = []
    fetch_mock = ->(_title, lang) {
      calls << lang
      lang == "pt" ? "https://example.com/gilberto_gil_banner.jpg" : nil
    }

    artist.stub :fetch_wikipedia_image_url, fetch_mock do
      URI.stub :open, ->(*_a) { File.open(Rails.root.join("db/seeds/images/dark_side_cover.png")) } do
        assert artist.update_banner_from_wikipedia
        assert artist.banner.attached?
        assert_equal ["en", "pt"], calls
      end
    end
  end

  test "should generate correct initials for different names" do
    assert_equal "JC", Artist.new(name: "John Coltrane").initials
    assert_equal "PF", Artist.new(name: "Pink Floyd").initials
    assert_equal "TB", Artist.new(name: "The Beatles").initials
    assert_equal "AD", Artist.new(name: "Adele").initials
    assert_equal "GG", Artist.new(name: "Gilberto Gil").initials
    assert_equal "", Artist.new(name: "").initials
    assert_equal "", Artist.new(name: nil).initials
  end
end
