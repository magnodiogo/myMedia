require "test_helper"
require "minitest/mock"

class AlbumTest < ActiveSupport::TestCase
  test "should be valid with required attributes" do
    album = Album.new(
      artist: artists(:queen),
      title: "News of the World",
      release_year: 1977
    )

    assert album.valid?
  end

  test "should expose primary artist alias" do
    album = albums(:night_at_the_opera)

    assert_equal artists(:queen), album.primary_artist
  end

  test "should be invalid without title" do
    album = Album.new(artist: artists(:queen))

    assert_not album.valid?
    assert_includes album.errors[:title], "can't be blank"
  end

  test "should be invalid without artist" do
    album = Album.new(title: "News of the World")

    assert_not album.valid?
    assert_includes album.errors[:artist], "must exist"
  end

  test "try_load_cover! returns true if cover is already attached" do
    album = albums(:night_at_the_opera)
    
    album.stub(:cover_image, Struct.new(:attached?).new(true)) do
      assert album.try_load_cover!
    end
  end

  test "try_load_cover! fetches from iTunes, downloads and saves cover" do
    album = albums(:kind_of_blue)
    assert_not album.cover_image.attached?

    test_instance = self
    album.define_singleton_method(:fetch_cover_from_itunes) { "https://example.com/cover.jpg" }
    album.define_singleton_method(:download_and_attach_cover) do |url|
      test_instance.assert_equal "https://example.com/cover.jpg", url
      true
    end

    assert album.try_load_cover!
  end

  test "try_load_cover! fallbacks to Discogs if iTunes fails" do
    album = albums(:kind_of_blue)
    assert_not album.cover_image.attached?

    test_instance = self
    album.define_singleton_method(:fetch_cover_from_itunes) { nil }
    album.define_singleton_method(:fetch_cover_from_discogs) { "https://example.com/discogs.jpg" }
    album.define_singleton_method(:download_and_attach_cover) do |url|
      test_instance.assert_equal "https://example.com/discogs.jpg", url
      true
    end

    assert album.try_load_cover!
  end

  test "try_load_cover! fallbacks to CAA if iTunes and Discogs fail" do
    album = albums(:kind_of_blue)
    album.update!(musicbrainz_release_group_id: "mb-123")
    assert_not album.cover_image.attached?

    test_instance = self
    album.define_singleton_method(:fetch_cover_from_itunes) { nil }
    album.define_singleton_method(:fetch_cover_from_discogs) { nil }
    album.define_singleton_method(:download_and_attach_cover) do |url|
      test_instance.assert_equal "https://coverartarchive.org/release-group/mb-123/front", url
      true
    end

    assert album.try_load_cover!
  end

  test "try_load_cover! returns false if all search adapters return nothing" do
    album = albums(:kind_of_blue)
    assert_not album.cover_image.attached?

    album.define_singleton_method(:fetch_cover_from_itunes) { nil }
    album.define_singleton_method(:fetch_cover_from_discogs) { nil }

    assert_not album.try_load_cover!
  end
end
