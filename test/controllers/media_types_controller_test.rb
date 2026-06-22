require "test_helper"

class MediaTypesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @media_type = MediaType.create!(name: "CD RedBook", description: "Audio CD")
    @admin = users(:two)
    sign_in @admin
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

  test "common user should not get new, edit, create, update, or destroy media type" do
    post switch_user_sessions_url, params: { user_id: users(:one).id }
    
    get new_media_type_url
    assert_redirected_to root_url
    assert_equal "Only administrator users can perform this action.", flash[:alert]

    get edit_media_type_url(@media_type)
    assert_redirected_to root_url

    assert_no_difference("MediaType.count") do
      post media_types_url, params: { media_type: { name: "New Format" } }
    end
    assert_redirected_to root_url

    patch media_type_url(@media_type), params: { media_type: { name: "Vinyl LP Updated" } }
    assert_redirected_to root_url
    @media_type.reload
    assert_not_equal "Vinyl LP Updated", @media_type.name

    assert_no_difference("MediaType.count") do
      delete media_type_url(@media_type)
    end
    assert_redirected_to root_url
  end
end
