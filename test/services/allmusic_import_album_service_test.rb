require "test_helper"

class AllmusicImportAlbumServiceTest < ActiveSupport::TestCase
  setup do
    @media = media(:two)
    @media.update!(allmusic_url: "https://www.allmusic.com/album/i-still-do-mw0002922480")
    @sample_html = Rails.root.join("test/fixtures/files/allmusic_i_still_do.html").read
  end

  test "imports album credits and returns parsed metadata" do
    service = Allmusic::ImportAlbumService.new(@media)
    html = @sample_html
    service.define_singleton_method(:download_html) { |_url| html }

    result = service.call

    assert result[:success]
    assert_nil result[:error]
    assert_equal "I Still Do", result[:parsed][:title]
    assert_equal "Eric Clapton", result[:parsed][:artist_name]
    assert_equal "May 20, 2016", result[:parsed][:release_date]
    assert_equal "54:10", result[:parsed][:duration]
    assert_equal "Pop/Rock", result[:parsed][:genre]
    assert_equal ["Album Rock", "Contemporary Pop/Rock"], result[:parsed][:styles]
    assert_equal "Stephen Thomas Erlewine", result[:parsed][:review_author]
    assert_equal "British Grove, London, UK", result[:parsed][:recording_location]

    @media.reload
    assert @media.allmusic_imported_at.present?
    assert_nil @media.allmusic_import_error
    assert_equal 3_250, @media.duration_seconds
    assert_equal "54:10", @media.formatted_duration
    assert_equal ["Pop/Rock"], @media.media_genres.order(:name).pluck(:name)
    assert_equal ["Album Rock", "Contemporary Pop/Rock"], @media.media_styles.order(:name).pluck(:name)
    assert_equal ["British Grove, London, UK"], @media.recording_locations.order(:name).pluck(:name)
    assert_equal 27, @media.album_credits.where(source: "allmusic").count
    assert @media.album_credits.where(person_name: "Leroy Carr", role: "Composer", credit_category: "composer").exists?
    assert @media.album_credits.where(person_name: "Dave Bronze", role: "Bass (Electric)", credit_category: "musician").exists?
    assert @media.album_credits.where(person_name: "Brice Beckham", role: "Layout", credit_category: "technical").exists?
    assert CreditPerson.exists?(name: "Leroy Carr")
    assert_credit("Eric Clapton", "Vocals")
    assert_credit("Glyn Johns", "Producer")
    assert_credit("Paul Carrack", "Organ (Hammond)")
    assert_credit("Henry Spinetti", "Drums")
    assert_credit("Chris Stainton", "Keyboards")
    assert_credit("Andy Fairweather Low", "Guitar (Electric)")
    assert_credit("Dave Bronze", "Bass (Electric)")
    assert_credit("Simon Climie", "Keyboards")
  end

  test "does not duplicate existing AllMusic credits or touch other sources" do
    @media.album_credits.create!(person_name: "Eric Clapton", role: "Vocals", source: "allmusic")
    @media.album_credits.create!(person_name: "Old AllMusic Person", role: "Old Role", source: "allmusic")
    @media.album_credits.create!(person_name: "Local Person", role: "Local Role", source: "local")

    service = Allmusic::ImportAlbumService.new(@media)
    html = @sample_html
    service.define_singleton_method(:download_html) { |_url| html }
    service.call

    assert_equal 1, @media.album_credits.where(person_name: "Eric Clapton", role: "Vocals", source: "allmusic").count
    assert_not @media.album_credits.exists?(person_name: "Old AllMusic Person", source: "allmusic")
    assert @media.album_credits.exists?(person_name: "Local Person", role: "Local Role", source: "local")
  end

  test "does not duplicate structured metadata links" do
    MediaGenre.create!(name: "Pop/Rock").media_genre_links.create!(media: @media)

    service = Allmusic::ImportAlbumService.new(@media)
    html = @sample_html
    service.define_singleton_method(:download_html) { |_url| html }
    service.call

    assert_equal 1, @media.media_genres.where(name: "Pop/Rock").count
  end

  test "returns early when AllMusic URL is blank" do
    @media.update!(allmusic_url: nil)

    result = Allmusic::ImportAlbumService.call(@media)

    assert_not result[:success]
    assert result[:skipped]
    assert_equal "AllMusic URL is blank", result[:error]
  end

  test "stores import error when download fails" do
    service = Allmusic::ImportAlbumService.new(@media)
    service.define_singleton_method(:download_html) { |_url| raise "Network unavailable" }

    result = service.call

    assert_not result[:success]
    assert_equal "Network unavailable", result[:error]
    assert_equal "Network unavailable", @media.reload.allmusic_import_error
  end

  test "media import helper calls the service" do
    original_call = Allmusic::ImportAlbumService.method(:call)
    called_with = nil
    Allmusic::ImportAlbumService.define_singleton_method(:call) do |media|
      called_with = media
      { success: true }
    end

    result = @media.import_allmusic!

    assert_equal @media, called_with
    assert_equal({ success: true }, result)
  ensure
    Allmusic::ImportAlbumService.define_singleton_method(:call) do |*args|
      original_call.call(*args)
    end
  end

  private

  def assert_credit(person_name, role)
    assert @media.album_credits.exists?(person_name: person_name, role: role, source: "allmusic"),
      "Expected #{person_name} | #{role} | allmusic"
  end
end
