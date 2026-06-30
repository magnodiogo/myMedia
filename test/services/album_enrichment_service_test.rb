require "test_helper"

class AlbumEnrichmentServiceTest < ActiveSupport::TestCase
  setup do
    @album = albums(:kind_of_blue)
    @album.update!(musicbrainz_release_group_id: "rg-kind-of-blue")
  end

  test "loads album metadata, tracks, lyrics, and performer credits" do
    service = AlbumEnrichmentService.new(@album)

    http_stub = lambda do |uri, _headers|
      case [uri.host, uri.path]
      when ["musicbrainz.org", "/ws/2/release-group/rg-kind-of-blue"]
        {
          "id" => "rg-kind-of-blue",
          "title" => "Kind of Blue",
          "primary-type" => "Album",
          "secondary-types" => [],
          "first-release-date" => "1959-08-17",
          "relations" => [
            { "type" => "wikidata", "url" => { "resource" => "https://www.wikidata.org/wiki/Q184111" } }
          ]
        }
      when ["musicbrainz.org", "/ws/2/release"]
        {
          "releases" => [
            {
              "id" => "release-kind-of-blue",
              "status" => "Official",
              "date" => "1959-08-17",
              "artist-credit" => [{ "artist" => { "name" => "Miles Davis" } }],
              "media" => [
                {
                  "position" => 1,
                  "tracks" => [
                    {
                      "number" => "1",
                      "length" => 562_000,
                      "recording" => {
                        "id" => "recording-so-what",
                        "title" => "So What",
                        "artist-credit" => [{ "artist" => { "name" => "Miles Davis" } }]
                      }
                    },
                    {
                      "number" => "2",
                      "length" => 567_000,
                      "recording" => {
                        "id" => "recording-freddie-freeloader",
                        "title" => "Freddie Freeloader",
                        "artist-credit" => [{ "artist" => { "name" => "Miles Davis" } }]
                      }
                    }
                  ]
                }
              ]
            }
          ]
        }
      when ["www.wikidata.org", "/wiki/Special:EntityData/Q184111.json"]
        {
          "entities" => {
            "Q184111" => {
              "sitelinks" => {
                "enwiki" => { "title" => "Kind of Blue" }
              }
            }
          }
        }
      when ["en.wikipedia.org", "/w/api.php"]
        {
          "query" => {
            "pages" => {
              "1" => {
                "title" => "Kind of Blue",
                "extract" => "Kind of Blue is a studio album by Miles Davis.",
                "fullurl" => "https://en.wikipedia.org/wiki/Kind_of_Blue"
              }
            }
          }
        }
      when ["lrclib.net", "/api/get"]
        { "plainLyrics" => "Imported lyrics" }
      else
        raise "Unexpected request: #{uri}"
      end
    end

    original_get_json = AlbumEnrichmentService::HttpClient.method(:get_json)
    AlbumEnrichmentService::HttpClient.define_singleton_method(:get_json, &http_stub)
    service.define_singleton_method(:cover_art_url) { |_release_group_id| nil }

    result = service.perform

    assert_nil result[:error]
    assert_equal 2, result[:imported_tracks]
    assert_equal 2, result[:lyrics_found]
    assert_equal 2, result[:credits_imported]

    @album.reload
    assert_equal "imported", @album.metadata_status
    assert_equal 1959, @album.release_year
    assert_equal Date.new(1959, 8, 17), @album.original_release_date
    assert_equal "Q184111", @album.wikidata_id
    assert_equal "https://en.wikipedia.org/wiki/Kind_of_Blue", @album.wikipedia_url
    assert_equal "Kind of Blue is a studio album by Miles Davis.", @album.summary

    assert_equal 2, @album.tracks.count
    track = @album.tracks.find_by!(musicbrainz_recording_id: "recording-so-what")
    assert_nil track.media
    assert_equal "So What", track.title
    assert_equal "9:22", track.duration
    assert_equal "Imported lyrics", track.lyrics
    assert_equal "Miles Davis", track.track_credits.first.name
  ensure
    AlbumEnrichmentService::HttpClient.define_singleton_method(:get_json) do |*args|
      original_get_json.call(*args)
    end
  end

  test "prefers original release tracklist and removes stale album tracks" do
    @album.tracks.create!(
      title: "Bonus Outtake",
      disc_number: 2,
      track_number: 1,
      position: "1",
      musicbrainz_recording_id: "recording-bonus"
    )

    service = AlbumEnrichmentService.new(@album)

    http_stub = lambda do |uri, _headers|
      case [uri.host, uri.path]
      when ["musicbrainz.org", "/ws/2/release-group/rg-kind-of-blue"]
        {
          "id" => "rg-kind-of-blue",
          "title" => "Kind of Blue",
          "primary-type" => "Album",
          "secondary-types" => [],
          "first-release-date" => "1959-08-17",
          "relations" => []
        }
      when ["musicbrainz.org", "/ws/2/release"]
        {
          "releases" => [
            {
              "id" => "release-deluxe",
              "status" => "Official",
              "date" => "2020",
              "title" => "Kind of Blue",
              "artist-credit" => [{ "artist" => { "name" => "Miles Davis" } }],
              "media" => [
                {
                  "position" => 1,
                  "tracks" => [
                    { "number" => "1", "recording" => { "id" => "recording-deluxe-1", "title" => "So What" } },
                    { "number" => "2", "recording" => { "id" => "recording-deluxe-2", "title" => "Freddie Freeloader" } },
                    { "number" => "3", "recording" => { "id" => "recording-deluxe-3", "title" => "Studio Sequence" } }
                  ]
                }
              ]
            },
            {
              "id" => "release-original",
              "status" => "Official",
              "date" => "1959-08-17",
              "title" => "Kind of Blue",
              "artist-credit" => [{ "artist" => { "name" => "Miles Davis" } }],
              "media" => [
                {
                  "position" => 1,
                  "tracks" => [
                    { "number" => "1", "recording" => { "id" => "recording-original-1", "title" => "So What" } },
                    { "number" => "2", "recording" => { "id" => "recording-original-2", "title" => "Freddie Freeloader" } }
                  ]
                }
              ]
            }
          ]
        }
      when ["lrclib.net", "/api/get"]
        {}
      else
        raise "Unexpected request: #{uri}"
      end
    end

    original_get_json = AlbumEnrichmentService::HttpClient.method(:get_json)
    AlbumEnrichmentService::HttpClient.define_singleton_method(:get_json, &http_stub)
    service.define_singleton_method(:cover_art_url) { |_release_group_id| nil }

    result = service.perform

    assert_nil result[:error]
    assert_equal 2, result[:imported_tracks]

    @album.reload
    assert_equal ["So What", "Freddie Freeloader"], @album.display_tracks.map(&:title)
    assert_nil @album.tracks.find_by(title: "Bonus Outtake")
    assert_nil @album.tracks.find_by(musicbrainz_recording_id: "recording-deluxe-3")
  ensure
    AlbumEnrichmentService::HttpClient.define_singleton_method(:get_json) do |*args|
      original_get_json.call(*args)
    end
  end
end
