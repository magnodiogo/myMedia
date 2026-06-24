require "test_helper"

class ArtistsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @artist = artists(:queen)
    @admin = users(:two) # Admin user from fixtures
    sign_in @admin
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

  test "common user should see discography and collection tabs" do
    sign_out @admin
    sign_in users(:one)
    @artist.update!(bio: "Queen biography. " * 40)

    get artist_url(@artist)

    assert_response :success
    assert_select ".tab-link", text: "Discography"
    assert_select ".tab-link", text: "My Collection"
    assert_select ".read-more-toggle", text: "More", minimum: 1
    assert_select ".discography-group-header h3", text: "Studio"
    assert_select "a[href=?]", album_path(albums(:night_at_the_opera)), minimum: 1
    assert_select ".artist-collection-grid .media-card", minimum: 1
    assert_select "form button", text: "Load Discography", count: 0
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

  test "common user should not get new, edit, create, update, or destroy artist" do
    sign_out @admin
    sign_in users(:one) # Common user
    
    get new_artist_url
    assert_redirected_to root_url
    assert_equal "Only administrator users can perform this action.", flash[:alert]

    get edit_artist_url(@artist)
    assert_redirected_to root_url

    assert_no_difference("Artist.count") do
      post artists_url, params: { artist: { name: "New Artist" } }
    end
    assert_redirected_to root_url

    patch artist_url(@artist), params: { artist: { name: "Queen Updated" } }
    assert_redirected_to root_url
    @artist.reload
    assert_not_equal "Queen Updated", @artist.name

    assert_no_difference("Artist.count") do
      delete artist_url(@artist)
    end
    assert_redirected_to root_url
  end

  test "admin should be able to trigger update_wiki" do
    Artist.class_eval do
      alias_method :orig_update_bio, :update_bio_from_wikipedia
      def update_bio_from_wikipedia; true; end
    end

    begin
      post update_wiki_artist_url(@artist)
      assert_redirected_to edit_artist_url(@artist)
      assert_equal "Artist biography successfully updated from Wikipedia.", flash[:notice]
    ensure
      Artist.class_eval do
        alias_method :update_bio_from_wikipedia, :orig_update_bio
        remove_method :orig_update_bio
      end
    end
  end

  test "admin should see error if update_wiki fails" do
    Artist.class_eval do
      alias_method :orig_update_bio, :update_bio_from_wikipedia
      def update_bio_from_wikipedia; false; end
    end

    begin
      post update_wiki_artist_url(@artist)
      assert_redirected_to edit_artist_url(@artist)
      assert_equal "Could not find a Wikipedia biography for this artist.", flash[:alert]
    ensure
      Artist.class_eval do
        alias_method :update_bio_from_wikipedia, :orig_update_bio
        remove_method :orig_update_bio
      end
    end
  end

  test "common user should not be able to trigger update_wiki" do
    sign_out @admin
    sign_in users(:one) # Common user

    post update_wiki_artist_url(@artist)
    assert_redirected_to root_url
    assert_equal "Only administrator users can perform this action.", flash[:alert]
  end

  test "admin should be able to trigger update_photo" do
    Artist.class_eval do
      alias_method :orig_update_photo, :update_photo_from_wikipedia
      def update_photo_from_wikipedia; true; end
    end

    begin
      post update_photo_artist_url(@artist)
      assert_redirected_to edit_artist_url(@artist)
      assert_equal "Artist photo successfully updated from Wikipedia.", flash[:notice]
    ensure
      Artist.class_eval do
        alias_method :update_photo_from_wikipedia, :orig_update_photo
        remove_method :orig_update_photo
      end
    end
  end

  test "admin should see error if update_photo fails" do
    Artist.class_eval do
      alias_method :orig_update_photo, :update_photo_from_wikipedia
      def update_photo_from_wikipedia; false; end
    end

    begin
      post update_photo_artist_url(@artist)
      assert_redirected_to edit_artist_url(@artist)
      assert_equal "Could not find a Wikipedia photo for this artist.", flash[:alert]
    ensure
      Artist.class_eval do
        alias_method :update_photo_from_wikipedia, :orig_update_photo
        remove_method :orig_update_photo
      end
    end
  end

  test "common user should not be able to trigger update_photo" do
    sign_out @admin
    sign_in users(:one) # Common user

    post update_photo_artist_url(@artist)
    assert_redirected_to root_url
    assert_equal "Only administrator users can perform this action.", flash[:alert]
  end

  test "admin should be able to load discography" do
    Artist.class_eval do
      alias_method :orig_load_discography, :load_discography
      def load_discography
        { imported: 2, updated: 1, skipped: 0, error: nil }
      end
    end

    begin
      post load_discography_artist_url(@artist)
      assert_redirected_to artist_url(@artist)
      assert_equal "Discography loaded: 2 imported, 1 updated, 0 skipped.", flash[:notice]
    ensure
      Artist.class_eval do
        alias_method :load_discography, :orig_load_discography
        remove_method :orig_load_discography
      end
    end
  end

  test "admin should see error if load discography fails" do
    Artist.class_eval do
      alias_method :orig_load_discography, :load_discography
      def load_discography
        { imported: 0, updated: 0, skipped: 0, error: "Artist not found on MusicBrainz." }
      end
    end

    begin
      post load_discography_artist_url(@artist)
      assert_redirected_to artist_url(@artist)
      assert_equal "Artist not found on MusicBrainz.", flash[:alert]
    ensure
      Artist.class_eval do
        alias_method :load_discography, :orig_load_discography
        remove_method :orig_load_discography
      end
    end
  end

  test "common user should not be able to load discography" do
    sign_out @admin
    sign_in users(:one)

    post load_discography_artist_url(@artist)
    assert_redirected_to root_url
    assert_equal "Only administrator users can perform this action.", flash[:alert]
  end
end
