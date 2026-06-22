require "test_helper"
require "minitest/mock"

class BarcodeLookupServiceTest < ActiveSupport::TestCase
  test "should register and lookup barcodes using adapters" do
    assert_includes BarcodeLookupService::ADAPTERS, BarcodeAdapters::Itunes
    assert_includes BarcodeLookupService::ADAPTERS, BarcodeAdapters::Discogs
    assert_includes BarcodeLookupService::ADAPTERS, BarcodeAdapters::Musicbrainz
  end

  test "Discogs adapter returns correct structure and falls back to release details for cover image" do
    barcode = "602438472529"
    adapter = BarcodeAdapters::Discogs.new(barcode)

    # Mock the search response (cover_image and thumb are empty)
    search_response = {
      "results" => [
        {
          "id" => 21095407,
          "title" => "Eric Clapton - The Lady In The Balcony: Lockdown Sessions",
          "year" => "2021",
          "catno" => "MSDB847252",
          "cover_image" => "",
          "thumb" => ""
        }
      ]
    }

    # Mock the release details response
    release_response = {
      "id" => 21095407,
      "images" => [
        {
          "type" => "primary",
          "uri" => "https://i.discogs.com/primary_image.jpg"
        }
      ]
    }

    adapter.stub :fetch_json, ->(url, _headers) {
      if url.include?("database/search")
        search_response
      elsif url.include?("releases/21095407")
        release_response
      else
        nil
      end
    } do
      result = adapter.lookup

      assert_equal "Discogs", result[:source]
      assert_equal "The Lady In The Balcony: Lockdown Sessions", result[:title]
      assert_equal "Eric Clapton", result[:artist]
      assert_equal "2021", result[:year]
      assert_equal "MSDB847252", result[:catalog]
      assert_equal "https://i.discogs.com/primary_image.jpg", result[:cover_url]
    end
  end

  test "MediaEnrichmentService enriches media via title and artist if barcode is blank" do
    media_type = MediaType.find_or_create_by!(name: "CD Test Unique") do |mt|
      mt.description = "Audio CD"
    end
    media = Media.create!(
      media_type: media_type,
      title: "The Lady In The Balcony",
      artist: "Eric Clapton"
    )

    enricher = MediaEnrichmentService.new(media)

    discogs_search_response = {
      "results" => [
        {
          "id" => 21095407,
          "title" => "Eric Clapton - The Lady In The Balcony: Lockdown Sessions"
        }
      ]
    }

    discogs_release_response = {
      "id" => 21095407,
      "title" => "The Lady In The Balcony: Lockdown Sessions",
      "year" => 2021,
      "labels" => [{"catno" => "MSDB847252"}],
      "artists" => [{"id" => 11059, "name" => "Eric Clapton"}],
      "images" => [{"uri" => "https://i.discogs.com/primary.jpg"}],
      "tracklist" => [
        {"position" => "1", "title" => "Nobody Knows You When You're Down and Out", "duration" => "3:00", "extraartists" => [{"name" => "Jimmy Cox", "role" => "Written-By"}]},
        {"position" => "2", "title" => "Golden Ring", "duration" => "2:40"}
      ]
    }

    # Stub the HttpClient get_json requests
    MediaEnrichmentService::HttpClient.stub :get_json, ->(uri, _headers) {
      url_str = uri.to_s
      if url_str.include?("database/search")
        discogs_search_response
      elsif url_str.include?("releases/21095407")
        discogs_release_response
      elsif url_str.include?("artists/11059")
        {"images" => [{"uri" => "https://i.discogs.com/artist.jpg"}]}
      else
        {}
      end
    } do
      # Also stub fetch_lyrics to prevent actual internet calls
      enricher.stub :fetch_lyrics, { found: true, lyrics: "Test lyrics" } do
        enricher.perform

        media.reload
        assert_equal "The Lady In The Balcony", media.title
        assert_equal "2021", media.release_year.to_s
        assert_equal "MSDB847252", media.catalog_number
        assert_equal "Eric Clapton", media.artist.name
        
        # Verify tracks were created
        assert_equal 2, media.tracks.count
        first_track = media.tracks.first
        assert_equal "Nobody Knows You When You're Down and Out", first_track.title
        assert_equal "Test lyrics", first_track.lyrics

        # Verify track credits were created
        assert_equal 1, first_track.track_credits.count
        assert_equal "Written-By", first_track.track_credits.first.function
        assert_equal "Jimmy Cox", first_track.track_credits.first.name
      end
    end
  end
end
