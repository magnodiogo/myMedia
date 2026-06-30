require "test_helper"
require "minitest/mock"

class AlbumsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    sign_in @user
    @album = albums(:kind_of_blue)
    @media = media(:two)
    @cd = media_types(:one)
    @lp = MediaType.for_release_format("LP")
    @track = Track.create!(
      media: @media,
      title: "So What",
      track_number: 1,
      duration: "9:22",
      lyrics: "So What lyrics"
    )
    @track.track_credits.create!(function: "Trumpet", name: "Miles Davis")
  end

  test "should show album" do
    @album.album_releases.create!(
      title: "Kind of Blue Legacy Edition",
      release_year: 1997,
      media_type: @cd,
      label: "Columbia / Legacy",
      catalog_number: "CK 64935",
      info: "Remastered release."
    )

    get album_url(@album)

    assert_response :success
    assert_select "h1.page-title", text: @album.title
    assert_select ".tab-link", text: "Tracks"
    assert_select ".tab-link", text: "Releases"
    assert_select ".tab-link", text: "Info"
    assert_select ".tab-link", text: "Fun Facts"
    assert_select ".tab-link", text: "Curiosities"
    assert_select ".tab-link", text: "Participants"
    assert_select ".tab-link", text: "My Collection"
    assert_select ".track-row", minimum: 1
    assert_select ".participant-row", minimum: 1
    assert_select ".album-releases-list .album-release-row", minimum: 1
    assert_select ".album-release-row h4", text: "Kind of Blue Legacy Edition"
    assert_select ".album-release-row", text: /Columbia \/ Legacy/
    assert_select ".album-release-row", text: /CK 64935/
  end

  test "admin should load album metadata" do
    sign_in users(:two)
    @media.update!(allmusic_url: "https://www.allmusic.com/album/i-still-do-mw0002922480")
    fake_service = Struct.new(:album) do
      def perform
        { imported_tracks: 2, updated_tracks: 1, lyrics_found: 2, credits_imported: 2 }
      end
    end

    original_new = AlbumEnrichmentService.method(:new)
    AlbumEnrichmentService.define_singleton_method(:new) { |album| fake_service.new(album) }

    begin
      post load_metadata_album_url(@album)
    ensure
      AlbumEnrichmentService.define_singleton_method(:new) do |*args|
        original_new.call(*args)
      end
    end

    assert_redirected_to album_url(@album.reload)
    assert_nil @album.reload.allmusic_url
    assert_equal "Album data loaded. Tracks imported: 2, tracks updated: 1, lyrics found: 2.", flash[:notice]
  end

  test "admin should update album allmusic url" do
    sign_in users(:two)
    allmusic_url = "https://www.allmusic.com/album/kind-of-blue-mw0000192322"

    patch update_allmusic_url_album_url(@album), params: { album: { allmusic_url: allmusic_url } }

    assert_redirected_to album_url(@album.reload)
    assert_equal allmusic_url, @album.allmusic_url
    assert_equal "AllMusic album link saved.", flash[:notice]
  end

  test "admin load metadata should search allmusic when album url is blank" do
    sign_in users(:two)
    @album.update!(allmusic_url: nil)
    @media.update!(allmusic_url: nil)
    fake_service = Struct.new(:album) do
      def perform
        { imported_tracks: 0, updated_tracks: 0, lyrics_found: 0 }
      end
    end

    original_new = AlbumEnrichmentService.method(:new)
    AlbumEnrichmentService.define_singleton_method(:new) { |album| fake_service.new(album) }

    begin
      post load_metadata_album_url(@album)
    ensure
      AlbumEnrichmentService.define_singleton_method(:new) { |*args| original_new.call(*args) }
    end

    assert_redirected_to album_url(@album.reload)
    assert_nil @album.allmusic_url
    assert_equal "Album data loaded. Tracks imported: 0, tracks updated: 0, lyrics found: 0.", flash[:notice]
  end

  test "common user should not load album metadata" do
    post load_metadata_album_url(@album)

    assert_redirected_to root_path
  end

  test "admin should get edit album page" do
    sign_in users(:two) # admin
    get edit_album_url(@album)
    assert_response :success
    assert_select "h1", text: "Edit Album"
    # assert_select "h3", text: "Album Releases"
    # assert_select "input[name*='[album_releases_attributes]'][name$='[title]']", minimum: 1
  end

  test "admin should update album details and virtual attributes" do
    sign_in users(:two) # admin
    patch album_url(@album), params: {
      album: {
        title: "Kind of Blue Updated",
        release_year: 1959,
        formatted_duration: "45:30",
        genre_names: "Jazz, Modal Jazz",
        style_names: "Cool Jazz",
        recording_location_names: "Columbia 30th Street Studio",
        summary: "An updated summary of the legendary jazz album.",
        fun_facts: "<p>Recorded in two sessions in 1959.</p>",
        manual_credits_text: "Miles Davis - Trumpet\nJohn Coltrane - Tenor Saxophone",
        metadata_status: "reviewed"
      }
    }

    @album.reload
    assert_redirected_to album_url(@album.reload)
    assert_equal "reviewed", @album.metadata_status
    assert_equal "Kind of Blue Updated", @album.title
    assert_equal 2730, @album.duration_seconds # 45 * 60 + 30
    assert_includes @album.media_genres.map(&:name), "Jazz"
    assert_includes @album.media_genres.map(&:name), "Modal Jazz"
    assert_includes @album.media_styles.map(&:name), "Cool Jazz"
    assert_includes @album.recording_locations.map(&:name), "Columbia 30th Street Studio"
    assert_equal "An updated summary of the legendary jazz album.", @album.summary
    assert_equal "<p>Recorded in two sessions in 1959.</p>", @album.fun_facts
    
    # Assert manual credits got created/updated
    credits = @album.album_credits.order(:person_name)
    assert_equal 2, credits.count
    assert_equal "John Coltrane", credits.first.person_name
    assert_equal "Tenor Saxophone", credits.first.role
    assert_equal "manual", credits.first.source
    assert_equal "Miles Davis", credits.second.person_name
    assert_equal "Trumpet", credits.second.role
    assert_equal "manual", credits.second.source
  end

  test "admin should manage releases from album form" do
    sign_in users(:two)
    existing_release = @album.album_releases.create!(
      title: "Kind of Blue Original LP",
      release_year: 1959,
      media_type: @lp,
      label: "Columbia",
      catalog_number: "CL 1355"
    )

    assert_difference("AlbumRelease.count", 1) do
      patch album_url(@album), params: {
        album: {
          title: @album.title,
          album_releases_attributes: {
            "0" => {
              id: existing_release.id,
              title: "Kind of Blue Original Mono LP",
              release_year: 1959,
              media_type_id: @lp.id,
              label: "Columbia",
              catalog_number: "CL 1355",
              position: 1
            },
            "1" => {
              title: "Kind of Blue Legacy Edition",
              release_year: 1997,
              media_type_id: @cd.id,
              label: "Columbia / Legacy",
              catalog_number: "CK 64935",
              info: "Remastered CD release.",
              position: 2
            },
            "2" => {
              title: "",
              release_year: "",
              media_type_id: "",
              label: "",
              catalog_number: "",
              info: ""
            }
          }
        }
      }
    end

    assert_redirected_to album_url(@album.reload)
    assert_equal "Kind of Blue Original Mono LP", existing_release.reload.title
    new_release = @album.album_releases.find_by!(title: "Kind of Blue Legacy Edition")
    assert_equal 1997, new_release.release_year
    assert_equal @cd, new_release.media_type
    assert_equal "Columbia / Legacy", new_release.label
    assert_equal "CK 64935", new_release.catalog_number
    assert_equal "Remastered CD release.", new_release.info
  end

  test "admin should remove releases from album form" do
    sign_in users(:two)
    release = @album.album_releases.create!(title: "Release To Remove", release_year: 2001, media_type: @cd)

    assert_difference("AlbumRelease.count", -1) do
      patch album_url(@album), params: {
        album: {
          title: @album.title,
          album_releases_attributes: {
            "0" => { id: release.id, title: release.title, _destroy: "1" }
          }
        }
      }
    end

    assert_redirected_to album_url(@album.reload)
    assert_not AlbumRelease.exists?(release.id)
  end

  test "common user should not get edit album page" do
    sign_in users(:one) # common user
    get edit_album_url(@album)
    assert_redirected_to root_path
  end

  test "common user should not update album details" do
    sign_in users(:one) # common user
    patch album_url(@album), params: { album: { title: "Hacked Title" } }
    assert_redirected_to root_path
    assert_not_equal "Hacked Title", @album.reload.title
  end

  test "admin should try load cover successfully" do
    sign_in users(:two) # admin
    
    Album.class_eval do
      alias_method :original_try_load_cover!, :try_load_cover!
      def try_load_cover!
        true
      end
    end
    
    begin
      post try_load_cover_album_url(@album)
    ensure
      Album.class_eval do
        alias_method :try_load_cover!, :original_try_load_cover!
        remove_method :original_try_load_cover!
      end
    end
    
    assert_redirected_to album_url(@album)
    assert_equal "Album cover loaded successfully.", flash[:notice]
  end

  test "admin try load cover handle failure" do
    sign_in users(:two) # admin
    
    Album.class_eval do
      alias_method :original_try_load_cover!, :try_load_cover!
      def try_load_cover!
        false
      end
    end
    
    begin
      post try_load_cover_album_url(@album)
    ensure
      Album.class_eval do
        alias_method :try_load_cover!, :original_try_load_cover!
        remove_method :original_try_load_cover!
      end
    end
    
    assert_redirected_to album_url(@album)
    assert_equal "Could not find a cover on the internet for this album.", flash[:alert]
  end

  test "common user should not try load cover" do
    # common user is users(:one)
    post try_load_cover_album_url(@album)
    
    assert_redirected_to root_path
  end
end
