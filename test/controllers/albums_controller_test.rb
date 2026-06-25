require "test_helper"

class AlbumsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    sign_in @user
    @album = albums(:kind_of_blue)
    @media = media(:two)
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
    get album_url(@album)

    assert_response :success
    assert_select "h1.page-title", text: @album.title
    assert_select ".tab-link", text: "Tracks"
    assert_select ".tab-link", text: "Info"
    assert_select ".tab-link", text: "Curiosities"
    assert_select ".tab-link", text: "Participants"
    assert_select ".tab-link", text: "My Collection"
    assert_select ".track-row", minimum: 1
    assert_select ".participant-row", minimum: 1
  end

  test "admin should load album metadata" do
    sign_in users(:two)
    @media.update!(allmusic_url: "https://www.allmusic.com/album/i-still-do-mw0002922480")
    fake_service = Struct.new(:album) do
      def perform
        { imported_tracks: 2, updated_tracks: 1, lyrics_found: 2, credits_imported: 2 }
      end
    end
    fake_allmusic_result = {
      success: true,
      skipped: false,
      error: nil,
      parsed: {},
      credits: [
        { person_name: "Eric Clapton", role: "Vocals", source: "allmusic" },
        { person_name: "Glyn Johns", role: "Producer", source: "allmusic" }
      ]
    }
    allmusic_called_with = nil

    original_new = AlbumEnrichmentService.method(:new)
    original_call = Allmusic::ImportAlbumService.method(:call)
    AlbumEnrichmentService.define_singleton_method(:new) { |album| fake_service.new(album) }
    Allmusic::ImportAlbumService.define_singleton_method(:call) do |album|
      allmusic_called_with = album
      fake_allmusic_result
    end

    begin
      post load_metadata_album_url(@album)
    ensure
      AlbumEnrichmentService.define_singleton_method(:new) do |*args|
        original_new.call(*args)
      end
      Allmusic::ImportAlbumService.define_singleton_method(:call) do |*args|
        original_call.call(*args)
      end
    end

    assert_redirected_to album_url(@album.reload)
    assert_equal @album, allmusic_called_with
    assert_equal @media.allmusic_url, @album.reload.allmusic_url
    assert_equal "Album data loaded. Tracks imported: 2, tracks updated: 1, lyrics found: 2. AllMusic credits imported: 2.", flash[:notice]
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
    fake_allmusic_result = {
      success: true,
      skipped: false,
      error: nil,
      parsed: {},
      credits: []
    }
    found_url = "https://www.allmusic.com/album/kind-of-blue-mw0000192322"

    original_new = AlbumEnrichmentService.method(:new)
    original_search_call = Allmusic::AlbumSearchService.method(:call)
    original_import_call = Allmusic::ImportAlbumService.method(:call)
    AlbumEnrichmentService.define_singleton_method(:new) { |album| fake_service.new(album) }
    Allmusic::AlbumSearchService.define_singleton_method(:call) { |_album| found_url }
    Allmusic::ImportAlbumService.define_singleton_method(:call) { |_album| fake_allmusic_result }

    begin
      post load_metadata_album_url(@album)
    ensure
      AlbumEnrichmentService.define_singleton_method(:new) { |*args| original_new.call(*args) }
      Allmusic::AlbumSearchService.define_singleton_method(:call) { |*args| original_search_call.call(*args) }
      Allmusic::ImportAlbumService.define_singleton_method(:call) { |*args| original_import_call.call(*args) }
    end

    assert_redirected_to album_url(@album.reload)
    assert_equal found_url, @album.allmusic_url
    assert_equal "Album data loaded. Tracks imported: 0, tracks updated: 0, lyrics found: 0. AllMusic credits imported: 0.", flash[:notice]
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
        manual_credits_text: "Miles Davis - Trumpet\nJohn Coltrane - Tenor Saxophone",
        metadata_status: "reviewed"
      }
    }

    @album.reload
    assert_redirected_to album_url(@album)
    assert_equal "reviewed", @album.metadata_status
    assert_equal "Kind of Blue Updated", @album.title
    assert_equal 2730, @album.duration_seconds # 45 * 60 + 30
    assert_includes @album.media_genres.map(&:name), "Jazz"
    assert_includes @album.media_genres.map(&:name), "Modal Jazz"
    assert_includes @album.media_styles.map(&:name), "Cool Jazz"
    assert_includes @album.recording_locations.map(&:name), "Columbia 30th Street Studio"
    assert_equal "An updated summary of the legendary jazz album.", @album.summary
    
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
end
