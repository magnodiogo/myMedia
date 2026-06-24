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
    Allmusic::ImportAlbumService.define_singleton_method(:call) do |medium|
      allmusic_called_with = medium
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

    assert_redirected_to album_url(@album)
    assert_equal @media, allmusic_called_with
    assert_equal "Album data loaded. Tracks imported: 2, tracks updated: 1, lyrics found: 2. AllMusic credits imported: 2.", flash[:notice]
  end

  test "common user should not load album metadata" do
    post load_metadata_album_url(@album)

    assert_redirected_to root_path
  end
end
