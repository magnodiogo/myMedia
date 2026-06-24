require "test_helper"

class TrackTest < ActiveSupport::TestCase
  setup do
    @media = media(:two)
  end


  test "should be valid with valid attributes" do
    track = Track.new(media: @media, title: "So What", track_number: 1, duration: "9:22")
    assert track.valid?
  end

  test "should be valid with album only" do
    track = Track.new(album: albums(:kind_of_blue), title: "So What", track_number: 1, duration: "9:22")
    assert track.valid?
  end

  test "should assign album from media" do
    track = Track.create!(media: @media, title: "So What", track_number: 1, duration: "9:22")
    assert_equal @media.album, track.album
  end

  test "should be invalid without media or album" do
    track = Track.new(title: "So What", track_number: 1, duration: "9:22")
    assert_not track.valid?
    assert_includes track.errors[:base], "Track must belong to a media item or an album"
  end

  test "should support position attribute" do
    track = Track.new(media: @media, title: "Speak to Me", track_number: 1, duration: "1:30", position: "A1")
    assert track.valid?
    assert_equal "A1", track.position
  end

  test "should be invalid without title" do
    track = Track.new(media: @media, track_number: 1, duration: "9:22")
    assert_not track.valid?
    assert_includes track.errors[:title], "can't be blank"
  end

  test "should be invalid without track number" do
    track = Track.new(media: @media, title: "So What", duration: "9:22")
    assert_not track.valid?
    assert_includes track.errors[:track_number], "can't be blank"
  end

  test "should be invalid with non-integer track number" do
    track = Track.new(media: @media, title: "So What", track_number: "one")
    assert_not track.valid?
    assert_includes track.errors[:track_number], "is not a number"
  end

  test "should be invalid with negative or zero track number" do
    track = Track.new(media: @media, title: "So What", track_number: 0)
    assert_not track.valid?
    assert_includes track.errors[:track_number], "must be greater than 0"
  end

  test "should be invalid with non-matching duration format" do
    track = Track.new(media: @media, title: "So What", track_number: 1, duration: "9m22s")
    assert_not track.valid?
    assert_includes track.errors[:duration], "must be in MM:SS format"
  end

  test "should be valid with empty duration" do
    track = Track.new(media: @media, title: "So What", track_number: 1, duration: "")
    assert track.valid?
  end
end
