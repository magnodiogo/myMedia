require "test_helper"

class ArtistEraTest < ActiveSupport::TestCase
  setup do
    @artist = artists(:queen)
  end

  test "should be valid with required attributes" do
    artist_era = ArtistEra.new(artist: @artist, name: "Classic Era")

    assert artist_era.valid?
  end

  test "should require name" do
    artist_era = ArtistEra.new(artist: @artist)

    assert_not artist_era.valid?
    assert_includes artist_era.errors[:name], "can't be blank"
  end

  test "should require artist" do
    artist_era = ArtistEra.new(name: "Classic Era")

    assert_not artist_era.valid?
    assert_includes artist_era.errors[:artist], "must exist"
  end

  test "should require starts_on before or equal to ends_on" do
    artist_era = ArtistEra.new(
      artist: @artist,
      name: "Backwards Era",
      starts_on: Date.new(1975, 1, 1),
      ends_on: Date.new(1974, 12, 31)
    )

    assert_not artist_era.valid?
    assert_includes artist_era.errors[:starts_on], "must be before or equal to ends on"
  end

  test "should determine media membership from release year" do
    medium = media(:one)
    medium.update!(release_year: 1975)
    artist_era = ArtistEra.create!(
      artist: @artist,
      name: "Mid Seventies",
      starts_on: Date.new(1974, 1, 1),
      ends_on: Date.new(1976, 12, 31)
    )

    assert artist_era.includes_media?(medium)

    medium.update!(release_year: 1977)
    assert_not artist_era.includes_media?(medium)
  end
end
