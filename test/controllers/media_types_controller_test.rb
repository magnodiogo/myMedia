require "test_helper"

class MediaTypesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @media_type = MediaType.create!(name: "CD RedBook", description: "Audio CD")
  end

  test "should get index" do
    get media_types_url
    assert_response :success
  end

  test "should get new" do
    get new_media_type_url
    assert_response :success
  end

  test "should create media_type" do
    assert_difference("MediaType.count") do
      post media_types_url, params: { media_type: { name: "Vinyl LP", description: "12-inch vinyl" } }
    end

    assert_redirected_to media_types_url
  end

  test "should show media_type" do
    get media_type_url(@media_type)
    assert_response :success
  end

  test "should get edit" do
    get edit_media_type_url(@media_type)
    assert_response :success
  end

  test "should update media_type" do
    patch media_type_url(@media_type), params: { media_type: { name: "CD RedBook Updated", description: "Updated desc" } }
    assert_redirected_to media_types_url
    @media_type.reload
    assert_equal "CD RedBook Updated", @media_type.name
  end

  test "should destroy media_type" do
    assert_difference("MediaType.count", -1) do
      delete media_type_url(@media_type)
    end

    assert_redirected_to media_types_url
  end

  test "should not destroy media_type if it has media items" do
    Media.create!(media_type: @media_type, title: "Abbey Road", artist: "The Beatles")
    
    assert_no_difference("MediaType.count") do
      delete media_type_url(@media_type)
    end

    assert_redirected_to media_types_url
    assert_not_nil flash[:alert]
  end
end
