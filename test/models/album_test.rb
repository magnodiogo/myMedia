require "test_helper"

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
end
