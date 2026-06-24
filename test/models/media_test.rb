require "test_helper"
require "minitest/mock"
require "open-uri"

class MediaTest < ActiveSupport::TestCase
  setup do
    @media_type = MediaType.create!(name: "CD RedBook")
  end

  test "should be valid with all required fields" do
    media = Media.new(
      media_type: @media_type,
      title: "The Dark Side of the Moon",
      artist: "Pink Floyd",
      release_year: 1973
    )
    assert media.valid?
  end

  test "should support info attribute" do
    media = Media.new(
      media_type: @media_type,
      title: "Supernatural",
      artist: "Santana",
      info: "Santana's album Supernatural info text"
    )
    assert media.valid?
    assert_equal "Santana's album Supernatural info text", media.info
  end

  test "should assign album from media attributes" do
    media = Media.create!(
      media_type: @media_type,
      title: "Wish You Were Here",
      artist: "Pink Floyd",
      release_year: 1975,
      info: "Album summary"
    )

    assert media.album.present?
    assert_equal "Wish You Were Here", media.album.title
    assert_equal "Pink Floyd", media.album.artist.name
    assert_equal 1975, media.album.release_year
    assert_equal "Album summary", media.album.summary
  end

  test "should be invalid without a title" do
    media = Media.new(media_type: @media_type, artist: "Pink Floyd")
    assert_not media.valid?
    assert_includes media.errors[:title], "can't be blank"
  end

  test "should be invalid without an artist" do
    media = Media.new(media_type: @media_type, title: "The Dark Side of the Moon")
    assert_not media.valid?
    assert_includes media.errors[:artist], "can't be blank"
  end

  test "should be invalid without a media_type" do
    media = Media.new(title: "The Dark Side of the Moon", artist: "Pink Floyd")
    assert_not media.valid?
    assert_includes media.errors[:media_type], "must exist"
  end

  test "should validate release_year boundaries" do
    media = Media.new(
      media_type: @media_type,
      title: "The Dark Side of the Moon",
      artist: "Pink Floyd",
      release_year: 1799
    )
    assert_not media.valid?
    assert_includes media.errors[:release_year], "must be greater than or equal to 1800"

    media.release_year = Time.current.year + 6
    assert_not media.valid?
  end

  test "should be able to attach a cover_image" do
    media = Media.create!(
      media_type: @media_type,
      title: "Abbey Road",
      artist: "The Beatles"
    )
    assert_not media.cover_image.attached?

    media.cover_image.attach(
      io: File.open(Rails.root.join("db/seeds/images/dark_side_cover.png")),
      filename: "dark_side_cover.png",
      content_type: "image/png"
    )
    assert media.cover_image.attached?
  end

  test "should download cover from URL before saving" do
    URI.stub :open, ->(*_a) { File.open(Rails.root.join('db/seeds/images/dark_side_cover.png')) } do
      media = Media.new(
        media_type: @media_type,
        title: "Brothers in Arms",
        artist: "Dire Straits",
        cover_url: "https://example.com/brothers_in_arms.jpg"
      )
      assert media.save
      assert media.cover_image.attached?
      
      # Verify image dimensions are resized to <= 600x600 directly using ImageMagick identify
      path = ActiveStorage::Blob.service.path_for(media.cover_image.key)
      if system("which identify > /dev/null 2>&1")
        dimensions = `identify -format "%wx%h" #{path}`.split("x").map(&:to_i)
        assert_operator dimensions[0], :<=, 600
        assert_operator dimensions[1], :<=, 600
      else
        warn "Warning: ImageMagick 'identify' command not found, skipping image dimensions assertion."
      end
    end
  end

  test "should download cover from URL on persisted record without infinite recursion" do
    media = Media.create!(
      media_type: @media_type,
      title: "Brothers in Arms",
      artist: "Dire Straits"
    )
    
    URI.stub :open, ->(*_a) { File.open(Rails.root.join('db/seeds/images/dark_side_cover.png')) } do
      media.update!(cover_url: "https://example.com/brothers_in_arms.jpg")
      assert media.cover_image.attached?
    end
  end

  test "should destroy album credits when media is destroyed" do
    media = Media.create!(
      media_type: @media_type,
      title: "I Still Do",
      artist: "Eric Clapton"
    )
    media.album_credits.create!(person_name: "Glyn Johns", role: "Producer", source: "allmusic")

    assert_difference("AlbumCredit.count", -1) do
      media.destroy
    end
  end
end
