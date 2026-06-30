require "test_helper"

class AlbumReleasesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @album = albums(:kind_of_blue)
    @admin = users(:two)
    @common_user = users(:one)
    @cd = media_types(:one)
    @cassette = media_types(:two)
    @lp = MediaType.for_release_format("LP")
    @digital = MediaType.for_release_format("Digital")
    @release = AlbumRelease.create!(
      album: @album,
      title: "Kind of Blue",
      release_year: 1959,
      media_type: @lp,
      label: "Columbia",
      catalog_number: "CL 1355",
      info: "Original mono LP release."
    )
  end

  test "admin should create album release" do
    sign_in @admin

    assert_difference("AlbumRelease.count") do
      post album_album_releases_url(@album), params: {
        album_release: {
          title: "Kind of Blue Legacy Edition",
          release_year: 1997,
          media_type_id: @cd.id,
          label: "Columbia / Legacy",
          catalog_number: "CK 64935",
          info: "Remastered CD release."
        }
      }
    end

    assert_redirected_to album_url(@album)
    assert_equal "Kind of Blue Legacy Edition", AlbumRelease.last.title
  end

  test "admin should update album release" do
    sign_in @admin

    patch album_album_release_url(@album, @release), params: {
      album_release: {
        title: "Kind of Blue Updated",
        release_year: 1960,
        media_type_id: @cd.id
      }
    }

    assert_redirected_to album_url(@album)
    assert_equal "Kind of Blue Updated", @release.reload.title
    assert_equal 1960, @release.release_year
  end

  test "admin should delete album release" do
    sign_in @admin

    assert_difference("AlbumRelease.count", -1) do
      delete album_album_release_url(@album, @release)
    end

    assert_redirected_to album_url(@album)
  end

  test "admin should try loading release cover" do
    sign_in @admin

    AlbumRelease.class_eval do
      alias_method :orig_try_load_cover, :try_load_cover!
      def try_load_cover!; true; end
    end

    begin
      post try_load_cover_album_album_release_url(@album, @release)
    ensure
      AlbumRelease.class_eval do
        alias_method :try_load_cover!, :orig_try_load_cover
        remove_method :orig_try_load_cover
      end
    end

    assert_redirected_to album_url(@album)
    assert_equal "Release cover loaded successfully.", flash[:notice]
  end

  test "common user should add release to collection" do
    sign_in @common_user

    assert_difference("Media.count", 1) do
      assert_difference("UserMedia.count", 1) do
        post add_to_collection_album_album_release_url(@album, @release)
      end
    end

    medium = Media.last
    assert_redirected_to media_url(medium)
    assert_equal @release, medium.album_release
    assert_equal @album, medium.album
    assert_equal @release.title, medium.title
    assert_equal @release.release_year, medium.release_year
    assert_equal @release.catalog_number, medium.catalog_number
    assert_equal @release.info, medium.notes
    assert_equal @release.media_type, medium.media_type
    assert @common_user.media.exists?(medium.id)
  end

  test "common user should not add digital release to collection" do
    sign_in @common_user
    digital_release = AlbumRelease.create!(
      album: @album,
      title: "Kind of Blue Digital",
      release_year: 2011,
      media_type: @digital
    )

    assert_no_difference(["Media.count", "UserMedia.count"]) do
      post add_to_collection_album_album_release_url(@album, digital_release)
    end

    assert_redirected_to album_url(@album)
    assert_equal "Digital releases cannot be added to a physical collection.", flash[:alert]
  end

  test "common user should not manage album releases" do
    sign_in @common_user

    get new_album_album_release_url(@album)
    assert_redirected_to root_url

    assert_no_difference("AlbumRelease.count") do
      post album_album_releases_url(@album), params: {
        album_release: { title: "Blocked Release" }
      }
    end
    assert_redirected_to root_url
  end
end
