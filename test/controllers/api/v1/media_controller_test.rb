require "test_helper"
require "open-uri"

class Api::V1::MediaControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "API Import User",
      email: "api_import_user@example.com",
      password: "correctpassword",
      password_confirmation: "correctpassword",
      subscription_tier: "free"
    )
    @media_type = MediaType.create!(name: "API Import CD")
    @token = JsonWebToken.encode(user_id: @user.id)
  end

  test "import and add creates media, album, collection details, and cover" do
    URI.stub :open, ->(*_args) { File.open(Rails.root.join("db/seeds/images/dark_side_cover.png")) } do
      assert_difference("Media.count", 1) do
        assert_difference("Album.count", 1) do
          assert_difference("UserMedia.count", 1) do
            post api_v1_media_import_and_add_url, params: {
              media_type_id: @media_type.id,
              title: "API Imported Album",
              artist: "API Imported Artist",
              release_year: 1977,
              catalog_number: "API-1977",
              barcode: " 123-456 ",
              cover_url: "https://example.com/cover.jpg",
              notes: "Mobile notes",
              purchase_location: "Mobile Store",
              price_paid: "29.99",
              currency: "USD",
              purchase_date: "2026-07-17",
              physical_location: "Shelf M",
              condition: "NM",
              sleeve_condition: "VG+",
              is_signed: "1",
              is_sealed: "0",
              edition_notes: "Mobile first press"
            }, headers: auth_headers
          end
        end
      end
    end

    assert_response :created
    json = JSON.parse(response.body)
    user_medium = UserMedia.find(json.dig("user_media", "id"))
    medium = user_medium.media

    assert_equal @user, user_medium.user
    assert_equal @media_type, medium.media_type
    assert_equal "API Imported Album", medium.title
    assert_equal "API Imported Artist", medium.artist.name
    assert_equal "API Imported Album", medium.album.title
    assert_equal 1977, medium.release_year
    assert_equal "API-1977", medium.catalog_number
    assert_equal "123456", medium.barcode
    assert medium.cover_image.attached?

    assert_equal "Mobile notes", user_medium.notes
    assert_equal "Mobile Store", user_medium.purchase_location
    assert_equal BigDecimal("29.99"), user_medium.price_paid
    assert_equal "USD", user_medium.currency
    assert_equal Date.new(2026, 7, 17), user_medium.purchase_date
    assert_equal "Shelf M", user_medium.physical_location
    assert_equal "NM", user_medium.condition
    assert_equal "VG+", user_medium.sleeve_condition
    assert user_medium.is_signed
    assert_not user_medium.is_sealed
    assert_equal "Mobile first press", user_medium.edition_notes
    assert json.dig("user_media", "media", "cover_image_base64").present?
  end

  test "import and add reuses existing media by barcode and creates only collection record" do
    artist = Artist.create!(name: "Existing API Artist")
    album = Album.create!(artist: artist, title: "Existing API Album", release_year: 1980)
    existing = Media.create!(
      media_type: @media_type,
      artist: artist,
      album: album,
      title: "Existing API Album",
      release_year: 1980,
      barcode: "999888"
    )

    assert_no_difference("Media.count") do
      assert_difference("UserMedia.count", 1) do
        post api_v1_media_import_and_add_url, params: {
          media_type_id: @media_type.id,
          title: "Incoming Changed Title",
          artist: "Incoming Changed Artist",
          release_year: 2026,
          barcode: "999 888",
          user_media: {
            notes: "Nested mobile notes",
            condition: "M"
          }
        }, headers: auth_headers
      end
    end

    assert_response :created
    user_medium = UserMedia.last
    assert_equal existing, user_medium.media
    assert_equal "Existing API Album", existing.reload.title
    assert_equal "Existing API Artist", existing.artist.name
    assert_equal 1980, existing.release_year
    assert_equal "Nested mobile notes", user_medium.notes
    assert_equal "M", user_medium.condition
  end

  test "import and add is unauthorized without token" do
    post api_v1_media_import_and_add_url, params: { title: "Blocked" }

    assert_response :unauthorized
  end

  private

  def auth_headers
    { "Authorization" => "Bearer #{@token}" }
  end
end
