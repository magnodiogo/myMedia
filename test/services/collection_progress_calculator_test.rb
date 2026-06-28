require "test_helper"

class CollectionProgressCalculatorTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @artist = Artist.create!(name: "Progress Artist")
    @media_type = MediaType.create!(name: "Progress CD")

    @owned = Media.create!(
      artist: @artist,
      media_type: @media_type,
      title: "Owned Album",
      release_year: 1970
    )
    @missing = Media.create!(
      artist: @artist,
      media_type: @media_type,
      title: "Missing Album",
      release_year: 1971
    )
    UserMedia.create!(user: @user, media: @owned)
  end

  test "should calculate artist progress percentage" do
    progress = CollectionProgressCalculator.for_artist(@artist, user: @user)

    assert_equal 2, progress[:total_count]
    assert_equal 1, progress[:owned_count]
    assert_equal 50.0, progress[:percentage]
    assert_equal 1, progress[:missing_count]
    assert_equal [@missing.id], progress[:missing_media].pluck(:id)
  end

  test "should calculate zero percentage when target has no media" do
    empty_artist = Artist.create!(name: "Empty Progress Artist")
    progress = CollectionProgressCalculator.for_artist(empty_artist, user: @user)

    assert_equal 0, progress[:total_count]
    assert_equal 0, progress[:owned_count]
    assert_equal 0.0, progress[:percentage]
    assert_equal 0, progress[:missing_count]
  end

  test "should calculate artist era progress" do
    artist_era = ArtistEra.create!(
      artist: @artist,
      name: "Early Era",
      starts_on: Date.new(1970, 1, 1),
      ends_on: Date.new(1970, 12, 31)
    )

    progress = CollectionProgressCalculator.for_artist_era(artist_era, user: @user)

    assert_equal 1, progress[:total_count]
    assert_equal 1, progress[:owned_count]
    assert_equal 100.0, progress[:percentage]
  end

  test "should calculate collection list progress" do
    collection_list = CollectionList.create!(
      name: "Progress List",
      slug: "progress-list",
      list_type: "custom"
    )
    collection_list.collection_list_items.create!(media: @owned, position: 1)
    collection_list.collection_list_items.create!(media: @missing, position: 2)

    progress = CollectionProgressCalculator.for_collection_list(collection_list, user: @user)

    assert_equal 2, progress[:total_count]
    assert_equal 1, progress[:owned_count]
    assert_equal 50.0, progress[:percentage]
  end
end
