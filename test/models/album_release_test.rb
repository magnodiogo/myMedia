require "test_helper"

class AlbumReleaseTest < ActiveSupport::TestCase
  setup do
    @album = albums(:kind_of_blue)
  end

  test "should be valid with required attributes" do
    release = AlbumRelease.new(
      album: @album,
      title: "Kind of Blue",
      release_year: 1959,
      format: "LP"
    )

    assert release.valid?
  end

  test "should require title" do
    release = AlbumRelease.new(album: @album)

    assert_not release.valid?
    assert_includes release.errors[:title], "can't be blank"
  end

  test "should require album" do
    release = AlbumRelease.new(title: "Kind of Blue")

    assert_not release.valid?
    assert_includes release.errors[:album], "must exist"
  end

  test "should validate release year bounds" do
    release = AlbumRelease.new(album: @album, title: "Kind of Blue", release_year: 1799)

    assert_not release.valid?
    assert_includes release.errors[:release_year], "must be greater than or equal to 1800"
  end

  test "should require unique allmusic url" do
    url = "https://www.allmusic.com/album/release/kind-of-blue-mr0000000001"
    AlbumRelease.create!(album: @album, title: "Kind of Blue", allmusic_url: url)
    duplicate = AlbumRelease.new(album: @album, title: "Kind of Blue", allmusic_url: url)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:allmusic_url], "has already been taken"
  end

  test "should combine label and catalog" do
    release = AlbumRelease.new(label: "Columbia / Legacy", catalog_number: "CK 64935")

    assert_equal "Columbia / Legacy - CK 64935", release.label_and_catalog
  end

  test "should display album cover when release cover is missing" do
    @album.cover_image.attach(
      io: File.open(Rails.root.join("db/seeds/images/dark_side_cover.png")),
      filename: "dark_side_cover.png",
      content_type: "image/png"
    )
    release = AlbumRelease.create!(album: @album, title: "Kind of Blue", release_year: 1959)

    assert release.display_cover_attached?
    assert_equal @album.cover_image.blob, release.display_cover.blob
  end

  test "should not attach inherited album cover when creating media" do
    @album.cover_image.attach(
      io: File.open(Rails.root.join("db/seeds/images/dark_side_cover.png")),
      filename: "dark_side_cover.png",
      content_type: "image/png"
    )
    release = AlbumRelease.create!(album: @album, title: "Kind of Blue", release_year: 1959, format: "CD")

    medium = release.to_media

    assert_not medium.cover_image.attached?
  end

  test "should identify digital releases as non physical" do
    digital_release = AlbumRelease.new(album: @album, title: "Kind of Blue", format: "Digital")
    cd_release = AlbumRelease.new(album: @album, title: "Kind of Blue", format: "CD")

    assert_not digital_release.physical?
    assert cd_release.physical?
  end

  test "should not create media from digital release" do
    release = AlbumRelease.create!(album: @album, title: "Kind of Blue", release_year: 1959, format: "Digital")

    assert_raises(RuntimeError) { release.to_media }
  end
end
