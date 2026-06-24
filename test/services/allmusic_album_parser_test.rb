require "test_helper"

class AllmusicAlbumParserTest < ActiveSupport::TestCase
  setup do
    @sample_html = Rails.root.join("test/fixtures/files/allmusic_i_still_do.html").read
  end

  test "returns normalized album metadata and grouped credits" do
    parsed = Allmusic::AlbumParser.call(@sample_html)

    assert_equal "I Still Do", parsed[:title]
    assert_equal "Eric Clapton", parsed[:artist_name]
    assert_equal "May 20, 2016", parsed[:release_date]
    assert_equal "54:10", parsed[:duration]
    assert_equal "Pop/Rock", parsed[:genre]
    assert_equal ["Album Rock", "Contemporary Pop/Rock"], parsed[:styles]
    assert_equal "Stephen Thomas Erlewine", parsed[:review_author]
    assert_equal "British Grove, London, UK", parsed[:recording_location]

    clapton = parsed[:credits].find { |credit| credit[:person_name] == "Eric Clapton" }
    assert_includes clapton[:roles], "Vocals"
    assert_includes clapton[:roles], "Guitars"
    assert_equal "Eric Clapton Composer, Guitars, Primary Artist, Tambourine, Vocals", clapton[:raw_text]
  end

  test "parses structured credit lists" do
    html = <<~HTML
      <html>
        <body>
          <h1 class="album-title">Example Album</h1>
          <div class="album-artist"><a href="/artist/example">Example Artist</a></div>
          <ul class="credits">
            <li><a href="/artist/glyn-johns">Glyn Johns</a> Producer, Engineer</li>
          </ul>
        </body>
      </html>
    HTML

    parsed = Allmusic::AlbumParser.call(html)
    credit = parsed[:credits].first

    assert_equal "Example Album", parsed[:title]
    assert_equal "Example Artist", parsed[:artist_name]
    assert_equal "Glyn Johns", credit[:person_name]
    assert_equal ["Producer", "Engineer"], credit[:roles]
    assert_equal "https://www.allmusic.com/artist/glyn-johns", credit[:allmusic_url]
  end
end
