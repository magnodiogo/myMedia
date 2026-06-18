require "test_helper"

class ArtistsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @artist = artists(:queen)
  end

  test "should get index" do
    get artists_url
    assert_response :success
    assert_select "h1.page-title", text: "Artists"
  end

  test "should get new" do
    get new_artist_url
    assert_response :success
  end

  test "should create artist" do
    assert_difference("Artist.count") do
      post artists_url, params: { artist: { name: "Pink Floyd", bio: "Progressive rock band" } }
    end

    assert_redirected_to artists_url
  end

  test "should create artist with photo" do
    photo = fixture_file_upload(Rails.root.join("db/seeds/images/dark_side_cover.png"), "image/png")
    assert_difference("Artist.count") do
      post artists_url, params: { artist: { name: "Led Zeppelin", bio: "English rock band", photo: photo } }
    end

    assert_redirected_to artists_url
    assert Artist.last.photo.attached?
  end

  test "should show artist" do
    get artist_url(@artist)
    assert_response :success
    assert_select "h1.page-title", text: @artist.name
  end

  test "should get edit" do
    get edit_artist_url(@artist)
    assert_response :success
  end

  test "should update artist" do
    patch artist_url(@artist), params: { artist: { name: "Queen Updated", bio: "New bio" } }
    assert_redirected_to artists_url
    @artist.reload
    assert_equal "Queen Updated", @artist.name
  end

  test "should destroy artist" do
    assert_difference("Artist.count", -1) do
      delete artist_url(@artist)
    end

    assert_redirected_to artists_url
  end
end
