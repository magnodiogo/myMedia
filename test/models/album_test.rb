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

  test "display tracks should sort vinyl side positions naturally" do
    album = albums(:night_at_the_opera)
    medium = media(:one)
    album.tracks.destroy_all

    [
      ["B1", 1, "Side B Opener"],
      ["A2", 2, "Side A Second"],
      ["A1", 1, "Side A Opener"],
      ["B2", 2, "Side B Second"]
    ].each do |position, track_number, title|
      album.tracks.create!(
        media: medium,
        position: position,
        track_number: track_number,
        title: title
      )
    end

    assert_equal ["A1", "A2", "B1", "B2"], album.display_tracks.map(&:position)
  end

  test "display tracks should prefer album tracklist over physical media tracks" do
    album = albums(:night_at_the_opera)
    medium = media(:one)
    album.tracks.destroy_all

    album.tracks.create!(
      position: "A1",
      track_number: 1,
      title: "Canonical Opener"
    )
    medium.tracks.create!(
      position: "A1",
      track_number: 1,
      title: "Physical Copy Opener"
    )

    assert_equal ["Canonical Opener"], album.display_tracks.map(&:title)
  end

  test "display cover should prefer original release cover over physical media cover" do
    album = albums(:night_at_the_opera)
    medium = media(:one)
    album.update!(release_year: 1975)

    release = album.album_releases.create!(
      title: "A Night at the Opera",
      release_year: 1975,
      media_type: MediaType.for_release_format("LP")
    )
    release.cover_image.attach(
      io: File.open(Rails.root.join("db/seeds/images/dark_side_cover.png")),
      filename: "origin_cover.png",
      content_type: "image/png"
    )
    medium.cover_image.attach(
      io: File.open(Rails.root.join("db/seeds/images/dark_side_cover.png")),
      filename: "physical_cover.png",
      content_type: "image/png"
    )

    assert_equal release.cover_image.blob, album.display_cover.blob
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

  test "persist_manual_credits de-duplicates credit people by exact and transliterated name" do
    album = albums(:kind_of_blue)
    p1 = CreditPerson.create!(name: "Leon Michels")

    assert_no_difference "CreditPerson.count" do
      album.manual_credits_text = "Leon Michels - Producer\nLéon Michels - Saxophone"
      album.save!
    end

    assert_equal 2, album.album_credits.count
    assert_equal [p1, p1], album.album_credits.map(&:credit_person)
  end
end
