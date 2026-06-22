require "test_helper"

class Api::V1::UserMediaControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "API Test User",
      email: "api_test_media_sync@example.com",
      password: "correctpassword",
      password_confirmation: "correctpassword",
      subscription_tier: "free"
    )
    
    @other_user = User.create!(
      name: "Other User",
      email: "other_user_media_sync@example.com",
      password: "correctpassword",
      password_confirmation: "correctpassword",
      subscription_tier: "free"
    )
    
    @artist = Artist.create!(name: "Test API Sync Artist")
    @media_type = MediaType.create!(name: "Test API Sync Media Type")
    
    @media = Media.create!(
      title: "Test API Sync Media Title",
      artist: @artist,
      media_type: @media_type,
      release_year: 2020
    )
    
    cover = fixture_file_upload(Rails.root.join("db/seeds/images/dark_side_cover.png"), "image/png")
    @media.cover_image.attach(cover)
    
    @user_medium = UserMedia.create!(
      user: @user,
      media: @media,
      notes: "My API sync test notes",
      purchase_location: "Online Shop",
      price_paid: 19.99,
      currency: "USD",
      purchase_date: Date.current,
      condition: "M",
      sleeve_condition: "M"
    )
  end

  test "should fail to get user media list without token" do
    get api_v1_user_media_index_url
    assert_response :unauthorized
  end

  test "should get minimal user media list successfully with valid token" do
    token = JsonWebToken.encode(user_id: @user.id)

    get api_v1_user_media_index_url, headers: {
      "Authorization" => "Bearer #{token}"
    }

    assert_response :ok
    json = JSON.parse(response.body)

    assert_kind_of Array, json
    assert_equal 1, json.length

    item = json.first
    assert_equal @user_medium.id, item["id"]
    assert_equal @media.id, item["media_id"]
    assert_not_nil item["updated_at"]
    
    # Assert that full details are NOT returned in listing
    assert_nil item["notes"]
    assert_nil item["media"]
  end

  test "should fail to get user media details without token" do
    get api_v1_user_media_url(@user_medium)
    assert_response :unauthorized
  end

  test "should get full user media details successfully with valid token" do
    token = JsonWebToken.encode(user_id: @user.id)

    get api_v1_user_media_url(@user_medium), headers: {
      "Authorization" => "Bearer #{token}"
    }

    assert_response :ok
    json = JSON.parse(response.body)

    assert_equal @user_medium.id, json["id"]
    assert_equal "My API sync test notes", json["notes"]
    assert_equal "Online Shop", json["purchase_location"]
    assert_equal "19.99", json["price_paid"]
    assert_equal "USD", json["currency"]

    # Verify nested media details
    media_json = json["media"]
    assert_not_nil media_json
    assert_equal @media.id, media_json["id"]
    assert_equal "Test API Sync Media Title", media_json["title"]
    assert_equal 2020, media_json["release_year"]
    
    # Verify nested artist and media type
    assert_equal @artist.id, media_json["artist"]["id"]
    assert_equal "Test API Sync Artist", media_json["artist"]["name"]
    assert_equal @media_type.id, media_json["media_type"]["id"]
    assert_equal "Test API Sync Media Type", media_json["media_type"]["name"]

    # Verify base64 cover image
    assert_not_nil media_json["cover_image_base64"]
    assert media_json["cover_image_base64"].start_with?("data:image/")
    assert media_json["cover_image_base64"].include?(";base64,")
  end

  test "should not show user media belonging to another user" do
    token = JsonWebToken.encode(user_id: @other_user.id)

    get api_v1_user_media_url(@user_medium), headers: {
      "Authorization" => "Bearer #{token}"
    }

    assert_response :not_found
  end
end
